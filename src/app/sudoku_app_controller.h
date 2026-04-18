#pragma once

#include "game/sudoku_app_state_store.h"
#include "game/sudoku_game.h"
#include "game/sudoku_generator.h"

#include <QTimer>
#include <QVariantList>
#include <qqmlregistration.h>

#include <array>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>

class SudokuAppController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(SudokuGame *game READ game CONSTANT)
    Q_PROPERTY(bool hasActiveSession READ hasActiveSession NOTIFY sessionChanged)
    Q_PROPERTY(QString activeDifficultyLabel READ activeDifficultyLabel NOTIFY sessionChanged)
    Q_PROPERTY(QString resumeSubtitle READ resumeSubtitle NOTIFY sessionChanged)
    Q_PROPERTY(QString resumePlayedText READ resumePlayedText NOTIFY sessionChanged)
    Q_PROPERTY(QString resumeStateText READ resumeStateText NOTIFY sessionChanged)
    Q_PROPERTY(QVariantList difficulties READ difficulties NOTIFY difficultiesChanged)
    Q_PROPERTY(bool showingMenu READ showingMenu NOTIFY showingMenuChanged)

public:
    explicit SudokuAppController(QObject *parent = nullptr);
    ~SudokuAppController() override;

    SudokuGame *game();
    bool hasActiveSession() const;
    QString activeDifficultyLabel() const;
    QString resumeSubtitle() const;
    QString resumePlayedText() const;
    QString resumeStateText() const;
    QVariantList difficulties() const;
    bool showingMenu() const;

    Q_INVOKABLE void startNewGame(const QString &difficultyId);
    Q_INVOKABLE void resumeGame();
    Q_INVOKABLE void showMenu();

signals:
    void sessionChanged();
    void difficultiesChanged();
    void showingMenuChanged();

private:
    static std::size_t difficultyIndex(SudokuDifficulty difficulty);
    static bool isValidPuzzle(const SudokuPuzzleData &puzzle);
    static QString formatElapsedSeconds(int elapsedSeconds);

    int currentElapsedSeconds() const;
    void loadState();
    void saveStateNow();
    void schedulePersist();
    void setShowingMenu(bool showingMenu);
    void updateElapsedProgress();
    void refreshElapsedTracking();
    void updateBestScore();
    void enqueueGeneration(SudokuDifficulty difficulty);
    void enqueueMissingPuzzles();
    void generationWorkerLoop();
    void handleGeneratedPuzzle(SudokuDifficulty difficulty, const SudokuPuzzleData &puzzle, bool success);
    QString difficultyStatusLabel(SudokuDifficulty difficulty) const;

    SudokuGame game_;
    SudokuAppStateStore stateStore_;
    SudokuGenerator generator_;
    QTimer persistTimer_;
    QTimer elapsedTimer_;
    std::array<int, kSudokuDifficultyCount> bestScores_{};
    std::array<bool, kSudokuDifficultyCount> hasCachedPuzzle_{};
    std::array<bool, kSudokuDifficultyCount> generationScheduled_{};
    std::array<SudokuPuzzleData, kSudokuDifficultyCount> cachedPuzzles_{};
    bool hasActiveSession_ = false;
    SudokuDifficulty activeDifficulty_ = SudokuDifficulty::Easy;
    bool showingMenu_ = true;
    int elapsedSeconds_ = 0;
    qint64 lastElapsedStartMs_ = -1;
    std::mutex generationMutex_;
    std::condition_variable generationReady_;
    std::deque<SudokuDifficulty> generationQueue_;
    std::thread generationWorker_;
    std::atomic<bool> stopGeneration_{false};
};
