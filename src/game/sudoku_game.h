#pragma once

#include "game/sudoku_app_state_store.h"
#include "game/sudoku_board.h"

#include <QAbstractListModel>
#include <qqmlregistration.h>

class SudokuGame : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool solved READ solved NOTIFY solvedChanged)
    Q_PROPERTY(int score READ score NOTIFY scoreChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
    Q_PROPERTY(bool notesMode READ notesMode NOTIFY notesModeChanged)
    Q_PROPERTY(int selectedCellIndex READ selectedCellIndex NOTIFY selectedCellIndexChanged)
    Q_PROPERTY(int selectedDigit READ selectedDigit NOTIFY selectedDigitChanged)

public:
    enum CellRole {
        ValueRole = Qt::UserRole + 1,
        GivenRole,
        EditableRole,
        CorrectRole,
        SelectedRole,
        NotesRole,
    };
    Q_ENUM(CellRole)

    explicit SudokuGame(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool solved() const;
    int score() const;
    bool paused() const;
    bool notesMode() const;
    int selectedCellIndex() const;
    int selectedDigit() const;
    bool loadPuzzle(const SudokuPuzzleData &puzzle);
    bool restoreSessionState(const SudokuGameSessionState &state);
    SudokuGameSessionState sessionState(SudokuDifficulty difficulty) const;

    Q_INVOKABLE void selectCell(int cellIndex);
    Q_INVOKABLE bool isPeerCell(int cellIndex) const;
    Q_INVOKABLE void enterDigit(int digit);
    Q_INVOKABLE void clearSelectedCell();
    Q_INVOKABLE void resetPuzzle();
    Q_INVOKABLE bool applyHint();
    Q_INVOKABLE void togglePaused();
    Q_INVOKABLE void toggleNotesMode();

signals:
    void solvedChanged();
    void scoreChanged();
    void pausedChanged();
    void notesModeChanged();
    void selectedCellIndexChanged();
    void selectedDigitChanged();

private:
    void emitCellStateChanged(int cellIndex, const QList<int> &roles);
    void emitBoardStateChanged();
    void emitSelectionStateChanged(int previousSelectedCell, int previousSelectedDigit);

    SudokuBoard board_;
    int selectedCell_ = -1;
    bool paused_ = false;
    bool notesMode_ = false;
};
