#include "game/sudoku_generator.h"

#include "qqwing.hpp"

#include <atomic>
#include <cstdlib>
#include <ctime>
#include <mutex>

namespace
{
qqwing::SudokuBoard::Difficulty toQqwingDifficulty(SudokuDifficulty difficulty)
{
    switch (difficulty) {
    case SudokuDifficulty::Easy:
        return qqwing::SudokuBoard::SIMPLE;
    case SudokuDifficulty::Medium:
        return qqwing::SudokuBoard::EASY;
    case SudokuDifficulty::Hard:
        return qqwing::SudokuBoard::INTERMEDIATE;
    case SudokuDifficulty::Extreme:
        return qqwing::SudokuBoard::EXPERT;
    }

    return qqwing::SudokuBoard::SIMPLE;
}

void seedQqwing()
{
    static std::once_flag seeded;
    std::call_once(seeded, [] {
        std::srand(static_cast<unsigned int>(std::time(nullptr)));
    });
}

std::mutex &qqwingMutex()
{
    static std::mutex mutex;
    return mutex;
}
}

bool SudokuGenerator::generate(
    SudokuDifficulty difficulty,
    SudokuPuzzleData &puzzle,
    const std::atomic<bool> *cancelled) const
{
    seedQqwing();

    while (cancelled == nullptr || !cancelled->load()) {
        qqwing::SudokuBoard board;
        board.setRecordHistory(true);

        {
            std::lock_guard<std::mutex> lock(qqwingMutex());
            board.generatePuzzleSymmetry(qqwing::SudokuBoard::NONE);
            board.solve();
        }

        if (board.getDifficulty() != toQqwingDifficulty(difficulty)) {
            continue;
        }

        puzzle.difficulty = difficulty;

        const int *givens = board.getPuzzle();
        const int *solution = board.getSolution();
        for (int index = 0; index < SudokuPuzzleData::cellCount; ++index) {
            puzzle.givens[index] = givens[index];
            puzzle.solution[index] = solution[index];
        }

        return true;
    }

    return false;
}
