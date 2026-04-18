#pragma once

#include "game/sudoku_puzzle.h"

#include <array>
#include <filesystem>

struct SudokuGameSessionState
{
    bool active = false;
    SudokuPuzzleData puzzle;
    bool paused = false;
    int elapsedSeconds = 0;
    bool notesMode = false;
    int selectedCell = -1;
    int mistakePenalty = 0;
    std::array<int, SudokuPuzzleData::cellCount> values{};
    std::array<int, SudokuPuzzleData::cellCount> noteMasks{};
    std::array<int, SudokuPuzzleData::cellCount> hintedCells{};
};

struct SudokuAppState
{
    SudokuGameSessionState session;
    std::array<int, kSudokuDifficultyCount> bestScores{};
    std::array<bool, kSudokuDifficultyCount> hasCachedPuzzle{};
    std::array<SudokuPuzzleData, kSudokuDifficultyCount> cachedPuzzles{};
};

class SudokuAppStateStore
{
public:
    explicit SudokuAppStateStore(std::filesystem::path statePath = defaultStatePath());

    bool load(SudokuAppState &state) const;
    bool save(const SudokuAppState &state) const;

    static std::filesystem::path defaultStatePath();

private:
    std::filesystem::path statePath_;
};
