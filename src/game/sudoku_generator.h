#pragma once

#include "game/sudoku_puzzle.h"

#include <atomic>

class SudokuGenerator
{
public:
    bool generate(SudokuDifficulty difficulty, SudokuPuzzleData &puzzle, const std::atomic<bool> *cancelled = nullptr) const;
};
