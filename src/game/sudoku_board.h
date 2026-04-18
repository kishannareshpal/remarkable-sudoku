#pragma once

#include "game/sudoku_puzzle.h"

#include <array>

class SudokuBoard
{
public:
    static constexpr int rowLength = 9;
    static constexpr int cellCount = rowLength * rowLength;

    SudokuBoard();

    void reset();
    bool loadPuzzle(const SudokuPuzzleData &puzzle);
    bool setValue(int index, int value);
    bool clearValue(int index);
    bool clearEntry(int index);
    bool toggleNote(int index, int digit);
    bool applyHint(int preferredIndex = -1, int *filledIndex = nullptr);
    void fillWithSolution();

    int valueAt(int index) const;
    int noteMaskAt(int index) const;
    const std::array<int, cellCount> &givens() const;
    const std::array<int, cellCount> &solution() const;
    int filledCells() const;
    int mistakeCount() const;
    int mistakePenalty() const;
    int score() const;
    std::array<int, cellCount> currentValues() const;
    std::array<int, cellCount> currentNotes() const;
    std::array<int, cellCount> currentHintedCells() const;
    bool restoreValues(const std::array<int, cellCount> &values);
    bool restoreNotes(const std::array<int, cellCount> &noteMasks);
    bool restoreHintedCells(const std::array<int, cellCount> &hintedCells);
    void setMistakePenalty(int mistakePenalty);

    bool isGiven(int index) const;
    bool isEditable(int index) const;
    bool isCorrect(int index) const;
    bool isSolved() const;

private:
    static bool isValidIndex(int index);
    static bool isValidValue(int value);

    std::array<int, cellCount> puzzle_;
    std::array<int, cellCount> solution_;
    std::array<int, cellCount> current_;
    std::array<int, cellCount> notes_{};
    std::array<int, cellCount> hintedCells_{};
    int mistakePenalty_ = 0;
};
