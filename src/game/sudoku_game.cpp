#include "game/sudoku_game.h"

SudokuGame::SudokuGame(QObject *parent)
    : QAbstractListModel(parent)
{
}

int SudokuGame::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return SudokuBoard::cellCount;
}

QVariant SudokuGame::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= SudokuBoard::cellCount) {
        return {};
    }

    const int cellIndex = index.row();

    switch (role) {
    case Qt::DisplayRole:
    case ValueRole:
        return board_.valueAt(cellIndex);
    case GivenRole:
        return board_.isGiven(cellIndex);
    case EditableRole:
        return board_.isEditable(cellIndex);
    case CorrectRole:
        return board_.isCorrect(cellIndex);
    case SelectedRole:
        return cellIndex == selectedCell_;
    case NotesRole:
        return board_.noteMaskAt(cellIndex);
    default:
        return {};
    }
}

QHash<int, QByteArray> SudokuGame::roleNames() const
{
    return {
        {ValueRole, "value"},
        {GivenRole, "given"},
        {EditableRole, "editable"},
        {CorrectRole, "correct"},
        {SelectedRole, "selected"},
        {NotesRole, "notes"},
    };
}

bool SudokuGame::solved() const
{
    return board_.isSolved();
}

int SudokuGame::score() const
{
    return board_.score();
}

bool SudokuGame::paused() const
{
    return paused_;
}

bool SudokuGame::notesMode() const
{
    return notesMode_;
}

int SudokuGame::selectedCellIndex() const
{
    return selectedCell_;
}

int SudokuGame::selectedDigit() const
{
    if (selectedCell_ < 0 || selectedCell_ >= SudokuBoard::cellCount) {
        return 0;
    }

    return board_.valueAt(selectedCell_);
}

bool SudokuGame::loadPuzzle(const SudokuPuzzleData &puzzle)
{
    const bool wasSolved = board_.isSolved();
    const int previousScore = board_.score();
    const bool wasPaused = paused_;
    const bool wasNotesMode = notesMode_;
    const int previousSelectedCell = selectedCell_;
    const int previousSelectedDigit = selectedDigit();

    if (!board_.loadPuzzle(puzzle)) {
        return false;
    }

    selectedCell_ = -1;
    paused_ = false;
    notesMode_ = false;

    emitBoardStateChanged();
    if (previousScore != board_.score()) {
        emit scoreChanged();
    }
    if (wasSolved != board_.isSolved()) {
        emit solvedChanged();
    }
    if (wasPaused != paused_) {
        emit pausedChanged();
    }
    if (wasNotesMode != notesMode_) {
        emit notesModeChanged();
    }
    emitSelectionStateChanged(previousSelectedCell, previousSelectedDigit);

    return true;
}

bool SudokuGame::restoreSessionState(const SudokuGameSessionState &state)
{
    const bool wasSolved = board_.isSolved();
    const int previousScore = board_.score();
    const bool wasPaused = paused_;
    const bool wasNotesMode = notesMode_;
    const int previousSelectedCell = selectedCell_;
    const int previousSelectedDigit = selectedDigit();

    if (!board_.loadPuzzle(state.puzzle)) {
        return false;
    }

    if (!board_.restoreValues(state.values)
        || !board_.restoreNotes(state.noteMasks)
        || !board_.restoreHintedCells(state.hintedCells)) {
        return false;
    }

    board_.setMistakePenalty(state.mistakePenalty);

    selectedCell_ = state.selectedCell >= 0 && state.selectedCell < SudokuBoard::cellCount
        ? state.selectedCell
        : -1;
    paused_ = state.paused;
    notesMode_ = state.notesMode;

    emitBoardStateChanged();
    if (previousScore != board_.score()) {
        emit scoreChanged();
    }
    if (wasSolved != board_.isSolved()) {
        emit solvedChanged();
    }
    if (wasPaused != paused_) {
        emit pausedChanged();
    }
    if (wasNotesMode != notesMode_) {
        emit notesModeChanged();
    }
    emitSelectionStateChanged(previousSelectedCell, previousSelectedDigit);

    return true;
}

SudokuGameSessionState SudokuGame::sessionState(SudokuDifficulty difficulty) const
{
    SudokuGameSessionState state;
    state.active = true;
    state.puzzle.difficulty = difficulty;
    state.puzzle.givens = board_.givens();
    state.puzzle.solution = board_.solution();
    state.paused = paused_;
    state.notesMode = notesMode_;
    state.selectedCell = selectedCell_;
    state.mistakePenalty = board_.mistakePenalty();
    state.values = board_.currentValues();
    state.noteMasks = board_.currentNotes();
    state.hintedCells = board_.currentHintedCells();
    return state;
}

void SudokuGame::selectCell(int cellIndex)
{
    if (paused_ || cellIndex < 0 || cellIndex >= SudokuBoard::cellCount || cellIndex == selectedCell_) {
        return;
    }

    const int previousCell = selectedCell_;
    const int previousDigit = selectedDigit();
    selectedCell_ = cellIndex;

    emitCellStateChanged(previousCell, {SelectedRole});
    emitCellStateChanged(selectedCell_, {SelectedRole});
    emitSelectionStateChanged(previousCell, previousDigit);
}

bool SudokuGame::isPeerCell(int cellIndex) const
{
    if (selectedCell_ < 0 || cellIndex < 0 || cellIndex >= SudokuBoard::cellCount || cellIndex == selectedCell_) {
        return false;
    }

    const int selectedRow = selectedCell_ / 9;
    const int selectedColumn = selectedCell_ % 9;
    const int row = cellIndex / 9;
    const int column = cellIndex % 9;

    return row == selectedRow
        || column == selectedColumn
        || ((row / 3) == (selectedRow / 3) && (column / 3) == (selectedColumn / 3));
}

void SudokuGame::enterDigit(int digit)
{
    if (paused_ || selectedCell_ < 0) {
        return;
    }

    if (notesMode_) {
        if (!board_.toggleNote(selectedCell_, digit)) {
            return;
        }

        emitCellStateChanged(selectedCell_, {NotesRole});
        return;
    }

    const bool wasSolved = board_.isSolved();
    const int previousScore = board_.score();
    const int previousSelectedDigit = selectedDigit();

    if (!board_.setValue(selectedCell_, digit)) {
        return;
    }

    emitCellStateChanged(selectedCell_, {ValueRole, CorrectRole, NotesRole});
    emitSelectionStateChanged(selectedCell_, previousSelectedDigit);
    if (previousScore != board_.score()) {
        emit scoreChanged();
    }
    if (wasSolved != board_.isSolved()) {
        emit solvedChanged();
    }
}

void SudokuGame::clearSelectedCell()
{
    if (paused_ || selectedCell_ < 0) {
        return;
    }

    const bool wasSolved = board_.isSolved();
    const int previousScore = board_.score();
    const int previousSelectedDigit = selectedDigit();

    if (!board_.clearEntry(selectedCell_)) {
        return;
    }

    emitCellStateChanged(selectedCell_, {ValueRole, CorrectRole, NotesRole});
    emitSelectionStateChanged(selectedCell_, previousSelectedDigit);
    if (previousScore != board_.score()) {
        emit scoreChanged();
    }
    if (wasSolved != board_.isSolved()) {
        emit solvedChanged();
    }
}

void SudokuGame::resetPuzzle()
{
    const bool wasSolved = board_.isSolved();
    const int previousScore = board_.score();
    const int previousSelectedCell = selectedCell_;
    const int previousSelectedDigit = selectedDigit();
    board_.reset();
    selectedCell_ = -1;

    emitBoardStateChanged();
    emitSelectionStateChanged(previousSelectedCell, previousSelectedDigit);
    if (previousScore != board_.score()) {
        emit scoreChanged();
    }
    if (wasSolved != board_.isSolved()) {
        emit solvedChanged();
    }
}

bool SudokuGame::applyHint()
{
    if (paused_ || board_.isSolved()) {
        return false;
    }

    const bool wasSolved = board_.isSolved();
    const int previousScore = board_.score();
    const int previousSelectedCell = selectedCell_;
    const int previousSelectedDigit = selectedDigit();
    int hintedCell = -1;

    if (!board_.applyHint(selectedCell_, &hintedCell) || hintedCell < 0) {
        return false;
    }

    selectedCell_ = hintedCell;

    if (previousSelectedCell != selectedCell_) {
        emitCellStateChanged(previousSelectedCell, {SelectedRole});
        emitCellStateChanged(selectedCell_, {SelectedRole});
    }

    emitCellStateChanged(hintedCell, {ValueRole, CorrectRole, NotesRole});
    emitSelectionStateChanged(previousSelectedCell, previousSelectedDigit);

    if (previousScore != board_.score()) {
        emit scoreChanged();
    }
    if (wasSolved != board_.isSolved()) {
        emit solvedChanged();
    }

    return true;
}

void SudokuGame::togglePaused()
{
    paused_ = !paused_;
    emit pausedChanged();
}

void SudokuGame::toggleNotesMode()
{
    if (paused_) {
        return;
    }

    notesMode_ = !notesMode_;
    emit notesModeChanged();
}

void SudokuGame::emitCellStateChanged(int cellIndex, const QList<int> &roles)
{
    if (cellIndex < 0 || cellIndex >= SudokuBoard::cellCount) {
        return;
    }

    emit dataChanged(index(cellIndex, 0), index(cellIndex, 0), roles);
}

void SudokuGame::emitBoardStateChanged()
{
    emit dataChanged(index(0, 0), index(SudokuBoard::cellCount - 1, 0), {
        ValueRole,
        GivenRole,
        EditableRole,
        CorrectRole,
        SelectedRole,
        NotesRole,
    });
}

void SudokuGame::emitSelectionStateChanged(int previousSelectedCell, int previousSelectedDigit)
{
    if (previousSelectedCell != selectedCell_) {
        emit selectedCellIndexChanged();
    }

    if (previousSelectedDigit != selectedDigit()) {
        emit selectedDigitChanged();
    }
}
