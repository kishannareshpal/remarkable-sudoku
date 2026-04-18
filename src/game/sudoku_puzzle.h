#pragma once

#include <array>
#include <cstddef>
#include <string_view>

enum class SudokuDifficulty : std::size_t {
    Easy = 0,
    Medium,
    Hard,
    Extreme,
};

constexpr std::size_t kSudokuDifficultyCount = 4;

constexpr std::array<SudokuDifficulty, kSudokuDifficultyCount> kSudokuDifficulties{
    SudokuDifficulty::Easy,
    SudokuDifficulty::Medium,
    SudokuDifficulty::Hard,
    SudokuDifficulty::Extreme,
};

inline constexpr const char *sudokuDifficultyId(SudokuDifficulty difficulty)
{
    switch (difficulty) {
    case SudokuDifficulty::Easy:
        return "easy";
    case SudokuDifficulty::Medium:
        return "medium";
    case SudokuDifficulty::Hard:
        return "hard";
    case SudokuDifficulty::Extreme:
        return "extreme";
    }

    return "easy";
}

inline constexpr const char *sudokuDifficultyLabel(SudokuDifficulty difficulty)
{
    switch (difficulty) {
    case SudokuDifficulty::Easy:
        return "Easy";
    case SudokuDifficulty::Medium:
        return "Medium";
    case SudokuDifficulty::Hard:
        return "Hard";
    case SudokuDifficulty::Extreme:
        return "Extreme";
    }

    return "Easy";
}

inline bool sudokuDifficultyFromString(std::string_view value, SudokuDifficulty &difficulty)
{
    for (SudokuDifficulty candidate : kSudokuDifficulties) {
        if (value == sudokuDifficultyId(candidate)) {
            difficulty = candidate;
            return true;
        }
    }

    return false;
}

struct SudokuPuzzleData
{
    static constexpr int cellCount = 81;

    SudokuDifficulty difficulty = SudokuDifficulty::Easy;
    std::array<int, cellCount> givens{};
    std::array<int, cellCount> solution{};
};
