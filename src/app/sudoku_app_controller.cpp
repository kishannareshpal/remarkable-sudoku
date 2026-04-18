#include "app/sudoku_app_controller.h"

#include "game/sudoku_board.h"

#include <QDateTime>
#include <QMetaObject>
#include <QVariantMap>

namespace
{
constexpr int kPersistDelayMs = 180;
}

SudokuAppController::SudokuAppController(QObject *parent)
    : QObject(parent)
{
    for (SudokuDifficulty difficulty : kSudokuDifficulties) {
        cachedPuzzles_[difficultyIndex(difficulty)].difficulty = difficulty;
    }

    persistTimer_.setSingleShot(true);
    persistTimer_.setInterval(kPersistDelayMs);
    connect(&persistTimer_, &QTimer::timeout, this, &SudokuAppController::saveStateNow);
    elapsedTimer_.setInterval(1000);
    connect(&elapsedTimer_, &QTimer::timeout, this, [this] {
        updateElapsedProgress();
        emit sessionChanged();
    });

    loadState();

    connect(&game_, &QAbstractItemModel::dataChanged, this, [this] {
        schedulePersist();
    });
    connect(&game_, &SudokuGame::scoreChanged, this, [this] {
        emit sessionChanged();
        schedulePersist();
    });
    connect(&game_, &SudokuGame::pausedChanged, this, [this] {
        refreshElapsedTracking();
        emit sessionChanged();
        schedulePersist();
    });
    connect(&game_, &SudokuGame::solvedChanged, this, [this] {
        refreshElapsedTracking();
        updateBestScore();
        emit sessionChanged();
        emit difficultiesChanged();
        schedulePersist();
    });
    connect(&game_, &SudokuGame::notesModeChanged, this, [this] {
        schedulePersist();
    });

    generationWorker_ = std::thread([this] {
        generationWorkerLoop();
    });

    enqueueMissingPuzzles();
    refreshElapsedTracking();
}

SudokuAppController::~SudokuAppController()
{
    updateElapsedProgress();
    elapsedTimer_.stop();
    stopGeneration_.store(true);
    generationReady_.notify_all();

    if (generationWorker_.joinable()) {
        generationWorker_.join();
    }

    persistTimer_.stop();
    saveStateNow();
}

SudokuGame *SudokuAppController::game()
{
    return &game_;
}

bool SudokuAppController::hasActiveSession() const
{
    return hasActiveSession_;
}

QString SudokuAppController::activeDifficultyLabel() const
{
    if (!hasActiveSession_) {
        return {};
    }

    return QString::fromLatin1(sudokuDifficultyLabel(activeDifficulty_));
}

QString SudokuAppController::resumeSubtitle() const
{
    if (!hasActiveSession_) {
        return {};
    }

    return QStringLiteral("%1 board").arg(activeDifficultyLabel());
}

QString SudokuAppController::resumePlayedText() const
{
    return formatElapsedSeconds(currentElapsedSeconds());
}

QString SudokuAppController::resumeStateText() const
{
    if (!hasActiveSession_) {
        return {};
    }

    if (game_.solved()) {
        return QStringLiteral("Solved");
    }

    if (game_.paused()) {
        return QStringLiteral("Paused");
    }

    return QStringLiteral("In progress");
}

QVariantList SudokuAppController::difficulties() const
{
    QVariantList list;
    list.reserve(static_cast<int>(kSudokuDifficultyCount));

    for (SudokuDifficulty difficulty : kSudokuDifficulties) {
        QVariantMap item;
        item.insert(QStringLiteral("id"), QString::fromLatin1(sudokuDifficultyId(difficulty)));
        item.insert(QStringLiteral("title"), QString::fromLatin1(sudokuDifficultyLabel(difficulty)));
        item.insert(QStringLiteral("ready"), hasCachedPuzzle_[difficultyIndex(difficulty)]);
        item.insert(QStringLiteral("status"), difficultyStatusLabel(difficulty));
        list.push_back(item);
    }

    return list;
}

bool SudokuAppController::showingMenu() const
{
    return showingMenu_;
}

void SudokuAppController::startNewGame(const QString &difficultyId)
{
    SudokuDifficulty difficulty;
    if (!sudokuDifficultyFromString(difficultyId.toStdString(), difficulty)) {
        return;
    }

    const std::size_t index = difficultyIndex(difficulty);
    if (!hasCachedPuzzle_[index]) {
        return;
    }

    const SudokuPuzzleData puzzle = cachedPuzzles_[index];
    if (!game_.loadPuzzle(puzzle)) {
        hasCachedPuzzle_[index] = false;
        cachedPuzzles_[index].difficulty = difficulty;
        emit difficultiesChanged();
        enqueueGeneration(difficulty);
        return;
    }

    hasCachedPuzzle_[index] = false;
    cachedPuzzles_[index] = {};
    cachedPuzzles_[index].difficulty = difficulty;
    hasActiveSession_ = true;
    activeDifficulty_ = difficulty;
    elapsedSeconds_ = 0;
    lastElapsedStartMs_ = -1;

    emit sessionChanged();
    emit difficultiesChanged();
    setShowingMenu(false);

    enqueueGeneration(difficulty);
    schedulePersist();
}

void SudokuAppController::resumeGame()
{
    if (!hasActiveSession_) {
        return;
    }

    setShowingMenu(false);
}

void SudokuAppController::showMenu()
{
    setShowingMenu(true);
}

std::size_t SudokuAppController::difficultyIndex(SudokuDifficulty difficulty)
{
    return static_cast<std::size_t>(difficulty);
}

bool SudokuAppController::isValidPuzzle(const SudokuPuzzleData &puzzle)
{
    SudokuBoard board;
    return board.loadPuzzle(puzzle);
}

QString SudokuAppController::formatElapsedSeconds(int elapsedSeconds)
{
    if (elapsedSeconds < 60) {
        return QStringLiteral("%1s").arg(elapsedSeconds);
    }

    if (elapsedSeconds < 3600) {
        const int minutes = elapsedSeconds / 60;
        const int seconds = elapsedSeconds % 60;
        return QStringLiteral("%1m %2s")
            .arg(minutes)
            .arg(seconds, 2, 10, QLatin1Char('0'));
    }

    const int hours = elapsedSeconds / 3600;
    const int minutes = (elapsedSeconds % 3600) / 60;
    return QStringLiteral("%1h %2m")
        .arg(hours)
        .arg(minutes, 2, 10, QLatin1Char('0'));
}

int SudokuAppController::currentElapsedSeconds() const
{
    if (!hasActiveSession_) {
        return 0;
    }

    if (lastElapsedStartMs_ < 0) {
        return elapsedSeconds_;
    }

    const qint64 elapsedMilliseconds = QDateTime::currentMSecsSinceEpoch() - lastElapsedStartMs_;
    if (elapsedMilliseconds <= 0) {
        return elapsedSeconds_;
    }

    return elapsedSeconds_ + static_cast<int>(elapsedMilliseconds / 1000);
}

void SudokuAppController::loadState()
{
    SudokuAppState state;
    if (!stateStore_.load(state)) {
        return;
    }

    for (SudokuDifficulty difficulty : kSudokuDifficulties) {
        const std::size_t index = difficultyIndex(difficulty);
        bestScores_[index] = std::max(0, state.bestScores[index]);
        if (state.hasCachedPuzzle[index] && isValidPuzzle(state.cachedPuzzles[index])) {
            hasCachedPuzzle_[index] = true;
            cachedPuzzles_[index] = state.cachedPuzzles[index];
            continue;
        }

        hasCachedPuzzle_[index] = false;
        cachedPuzzles_[index] = {};
        cachedPuzzles_[index].difficulty = difficulty;
    }

    if (!state.session.active || !isValidPuzzle(state.session.puzzle)) {
        return;
    }

    if (!game_.restoreSessionState(state.session)) {
        return;
    }

    hasActiveSession_ = true;
    activeDifficulty_ = state.session.puzzle.difficulty;
    elapsedSeconds_ = state.session.elapsedSeconds;
}

void SudokuAppController::saveStateNow()
{
    SudokuAppState state;

    if (hasActiveSession_) {
        state.session = game_.sessionState(activeDifficulty_);
        state.session.elapsedSeconds = currentElapsedSeconds();
    }

    state.bestScores = bestScores_;

    for (SudokuDifficulty difficulty : kSudokuDifficulties) {
        const std::size_t index = difficultyIndex(difficulty);
        state.hasCachedPuzzle[index] = hasCachedPuzzle_[index];
        state.cachedPuzzles[index] = cachedPuzzles_[index];
        state.cachedPuzzles[index].difficulty = difficulty;
    }

    stateStore_.save(state);
}

void SudokuAppController::schedulePersist()
{
    persistTimer_.start();
}

void SudokuAppController::setShowingMenu(bool showingMenu)
{
    if (showingMenu_ == showingMenu) {
        return;
    }

    showingMenu_ = showingMenu;
    refreshElapsedTracking();
    emit showingMenuChanged();
    emit sessionChanged();
}

void SudokuAppController::updateElapsedProgress()
{
    if (lastElapsedStartMs_ < 0) {
        return;
    }

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 elapsedMilliseconds = now - lastElapsedStartMs_;
    if (elapsedMilliseconds < 1000) {
        return;
    }

    const qint64 wholeSeconds = elapsedMilliseconds / 1000;
    elapsedSeconds_ += static_cast<int>(wholeSeconds);
    lastElapsedStartMs_ += wholeSeconds * 1000;
}

void SudokuAppController::refreshElapsedTracking()
{
    const bool shouldTrack = hasActiveSession_ && !showingMenu_ && !game_.paused() && !game_.solved();
    if (shouldTrack) {
        if (lastElapsedStartMs_ < 0) {
            lastElapsedStartMs_ = QDateTime::currentMSecsSinceEpoch();
        }

        if (!elapsedTimer_.isActive()) {
            elapsedTimer_.start();
        }
        return;
    }

    updateElapsedProgress();
    lastElapsedStartMs_ = -1;
    elapsedTimer_.stop();
}

void SudokuAppController::updateBestScore()
{
    if (!hasActiveSession_ || !game_.solved()) {
        return;
    }

    const std::size_t index = difficultyIndex(activeDifficulty_);
    bestScores_[index] = std::max(bestScores_[index], game_.score());
}

void SudokuAppController::enqueueGeneration(SudokuDifficulty difficulty)
{
    const std::size_t index = difficultyIndex(difficulty);
    if (hasCachedPuzzle_[index] || generationScheduled_[index] || stopGeneration_.load()) {
        return;
    }

    {
        std::lock_guard<std::mutex> lock(generationMutex_);
        generationScheduled_[index] = true;
        generationQueue_.push_back(difficulty);
    }

    emit difficultiesChanged();
    generationReady_.notify_one();
}

void SudokuAppController::enqueueMissingPuzzles()
{
    for (SudokuDifficulty difficulty : kSudokuDifficulties) {
        if (!hasCachedPuzzle_[difficultyIndex(difficulty)]) {
            enqueueGeneration(difficulty);
        }
    }
}

void SudokuAppController::generationWorkerLoop()
{
    while (!stopGeneration_.load()) {
        SudokuDifficulty difficulty = SudokuDifficulty::Easy;

        {
            std::unique_lock<std::mutex> lock(generationMutex_);
            generationReady_.wait(lock, [this] {
                return stopGeneration_.load() || !generationQueue_.empty();
            });

            if (stopGeneration_.load()) {
                return;
            }

            difficulty = generationQueue_.front();
            generationQueue_.pop_front();
        }

        SudokuPuzzleData puzzle;
        const bool success = generator_.generate(difficulty, puzzle, &stopGeneration_);
        if (stopGeneration_.load()) {
            return;
        }

        QMetaObject::invokeMethod(
            this,
            [this, difficulty, puzzle, success] {
                handleGeneratedPuzzle(difficulty, puzzle, success);
            },
            Qt::QueuedConnection);
    }
}

void SudokuAppController::handleGeneratedPuzzle(
    SudokuDifficulty difficulty,
    const SudokuPuzzleData &puzzle,
    bool success)
{
    const std::size_t index = difficultyIndex(difficulty);
    generationScheduled_[index] = false;

    if (success && isValidPuzzle(puzzle)) {
        hasCachedPuzzle_[index] = true;
        cachedPuzzles_[index] = puzzle;
    }

    emit difficultiesChanged();
    schedulePersist();
}

QString SudokuAppController::difficultyStatusLabel(SudokuDifficulty difficulty) const
{
    const std::size_t index = difficultyIndex(difficulty);
    if (hasCachedPuzzle_[index]) {
        if (bestScores_[index] > 0) {
            return QStringLiteral("Best: %1 Points").arg(bestScores_[index]);
        }

        return {};
    }

    return QStringLiteral("Preparing");
}
