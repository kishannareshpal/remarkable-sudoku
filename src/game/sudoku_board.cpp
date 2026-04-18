#include "game/sudoku_board.h"

#include <algorithm>
#include <random>
#include <vector>

namespace
{
constexpr int kAllNotesMask = (1 << SudokuBoard::rowLength) - 1;

constexpr std::array<int, SudokuBoard::cellCount> kPuzzle{
    5, 3, 0, 0, 7, 0, 0, 0, 0,
    6, 0, 0, 1, 9, 5, 0, 0, 0,
    0, 9, 8, 0, 0, 0, 0, 6, 0,
    8, 0, 0, 0, 6, 0, 0, 0, 3,
    4, 0, 0, 8, 0, 3, 0, 0, 1,
    7, 0, 0, 0, 2, 0, 0, 0, 6,
    0, 6, 0, 0, 0, 0, 2, 8, 0,
    0, 0, 0, 4, 1, 9, 0, 0, 5,
    0, 0, 0, 0, 8, 0, 0, 7, 9,
};

constexpr std::array<int, SudokuBoard::cellCount> kSolution{
    5, 3, 4, 6, 7, 8, 9, 1, 2,
    6, 7, 2, 1, 9, 5, 3, 4, 8,
    1, 9, 8, 3, 4, 2, 5, 6, 7,
    8, 5, 9, 7, 6, 1, 4, 2, 3,
    4, 2, 6, 8, 5, 3, 7, 9, 1,
    7, 1, 3, 9, 2, 4, 8, 5, 6,
    9, 6, 1, 5, 3, 7, 2, 8, 4,
    2, 8, 7, 4, 1, 9, 6, 3, 5,
    3, 4, 5, 2, 8, 6, 1, 7, 9,
};
}

SudokuBoard::SudokuBoard()
    : puzzle_(kPuzzle),
      solution_(kSolution),
      current_(kPuzzle)
{
}

void SudokuBoard::reset()
{
    current_ = puzzle_;
    notes_.fill(0);
    hintedCells_.fill(0);
    mistakePenalty_ = 0;
}

bool SudokuBoard::loadPuzzle(const SudokuPuzzleData &puzzle)
{
    for (int index = 0; index < cellCount; ++index) {
        const int given = puzzle.givens[index];
        const int solvedValue = puzzle.solution[index];
        if (given < 0 || given > rowLength || solvedValue < 1 || solvedValue > rowLength) {
            return false;
        }

        if (given != 0 && given != solvedValue) {
            return false;
        }
    }

    puzzle_ = puzzle.givens;
    solution_ = puzzle.solution;
    reset();
    return true;
}

bool SudokuBoard::setValue(int index, int value)
{
    if (!isEditable(index) || !isValidValue(value)) {
        return false;
    }

    if (current_[index] == value) {
        return false;
    }

    current_[index] = value;
    notes_[index] = 0;
    if (value != solution_[index]) {
        ++mistakePenalty_;
    }
    return true;
}

bool SudokuBoard::clearValue(int index)
{
    if (!isEditable(index) || current_[index] == 0) {
        return false;
    }

    current_[index] = 0;
    return true;
}

bool SudokuBoard::clearEntry(int index)
{
    if (!isEditable(index)) {
        return false;
    }

    if (current_[index] != 0) {
        current_[index] = 0;
        return true;
    }

    if (notes_[index] == 0) {
        return false;
    }

    notes_[index] = 0;
    return true;
}

bool SudokuBoard::toggleNote(int index, int digit)
{
    if (!isEditable(index) || current_[index] != 0 || !isValidValue(digit)) {
        return false;
    }

    notes_[index] ^= 1 << (digit - 1);
    return true;
}

bool SudokuBoard::applyHint(int preferredIndex, int *filledIndex)
{
    auto canFillIndex = [this](int index) {
        return isEditable(index) && current_[index] != solution_[index];
    };

    int targetIndex = -1;

    if (canFillIndex(preferredIndex)) {
        targetIndex = preferredIndex;
    } else {
        std::vector<int> candidates;
        candidates.reserve(cellCount);

        for (int index = 0; index < cellCount; ++index) {
            if (canFillIndex(index)) {
                candidates.push_back(index);
            }
        }

        if (candidates.empty()) {
            return false;
        }

        std::random_device randomDevice;
        std::mt19937 generator(randomDevice());
        std::uniform_int_distribution<int> distribution(0, static_cast<int>(candidates.size()) - 1);
        targetIndex = candidates[distribution(generator)];
    }

    current_[targetIndex] = solution_[targetIndex];
    notes_[targetIndex] = 0;
    hintedCells_[targetIndex] = 1;

    if (filledIndex) {
        *filledIndex = targetIndex;
    }

    return true;
}

void SudokuBoard::fillWithSolution()
{
    current_ = solution_;
    notes_.fill(0);
    hintedCells_.fill(0);
    mistakePenalty_ = 0;
}

int SudokuBoard::valueAt(int index) const
{
    if (!isValidIndex(index)) {
        return 0;
    }

    return current_[index];
}

int SudokuBoard::noteMaskAt(int index) const
{
    if (!isValidIndex(index)) {
        return 0;
    }

    return notes_[index];
}

const std::array<int, SudokuBoard::cellCount> &SudokuBoard::givens() const
{
    return puzzle_;
}

const std::array<int, SudokuBoard::cellCount> &SudokuBoard::solution() const
{
    return solution_;
}

int SudokuBoard::filledCells() const
{
    return static_cast<int>(std::count_if(
        current_.cbegin(),
        current_.cend(),
        [](int value) { return value != 0; }));
}

int SudokuBoard::mistakeCount() const
{
    int mistakes = 0;

    for (int index = 0; index < cellCount; ++index) {
        if (current_[index] != 0 && current_[index] != solution_[index]) {
            ++mistakes;
        }
    }

    return mistakes;
}

int SudokuBoard::mistakePenalty() const
{
    return mistakePenalty_;
}

int SudokuBoard::score() const
{
    int correctManualCells = 0;

    for (int index = 0; index < cellCount; ++index) {
        if (puzzle_[index] == 0
            && hintedCells_[index] == 0
            && current_[index] != 0
            && current_[index] == solution_[index]) {
            ++correctManualCells;
        }
    }

    return std::max(0, correctManualCells - mistakePenalty_);
}

std::array<int, SudokuBoard::cellCount> SudokuBoard::currentValues() const
{
    return current_;
}

std::array<int, SudokuBoard::cellCount> SudokuBoard::currentNotes() const
{
    return notes_;
}

std::array<int, SudokuBoard::cellCount> SudokuBoard::currentHintedCells() const
{
    return hintedCells_;
}

bool SudokuBoard::restoreValues(const std::array<int, cellCount> &values)
{
    for (int index = 0; index < cellCount; ++index) {
        const int value = values[index];
        if (value != 0 && !isValidValue(value)) {
            return false;
        }

        if (isGiven(index) && value != puzzle_[index]) {
            return false;
        }
    }

    current_ = values;
    return true;
}

bool SudokuBoard::restoreNotes(const std::array<int, cellCount> &noteMasks)
{
    for (int index = 0; index < cellCount; ++index) {
        const int noteMask = noteMasks[index];
        if (noteMask < 0 || noteMask > kAllNotesMask) {
            return false;
        }

        if (isGiven(index) || current_[index] != 0) {
            if (noteMask != 0) {
                return false;
            }
        }
    }

    notes_ = noteMasks;
    return true;
}

bool SudokuBoard::restoreHintedCells(const std::array<int, cellCount> &hintedCells)
{
    for (int index = 0; index < cellCount; ++index) {
        const int hinted = hintedCells[index];
        if (hinted < 0 || hinted > 1) {
            return false;
        }

        if (isGiven(index) && hinted != 0) {
            return false;
        }
    }

    hintedCells_ = hintedCells;
    return true;
}

void SudokuBoard::setMistakePenalty(int mistakePenalty)
{
    mistakePenalty_ = std::max(0, mistakePenalty);
}

bool SudokuBoard::isGiven(int index) const
{
    return isValidIndex(index) && puzzle_[index] != 0;
}

bool SudokuBoard::isEditable(int index) const
{
    return isValidIndex(index) && !isGiven(index);
}

bool SudokuBoard::isCorrect(int index) const
{
    if (!isValidIndex(index) || current_[index] == 0) {
        return true;
    }

    return current_[index] == solution_[index];
}

bool SudokuBoard::isSolved() const
{
    return current_ == solution_;
}

bool SudokuBoard::isValidIndex(int index)
{
    return index >= 0 && index < cellCount;
}

bool SudokuBoard::isValidValue(int value)
{
    return value >= 1 && value <= rowLength;
}
