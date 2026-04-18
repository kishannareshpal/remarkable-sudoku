#pragma once

#include "game/sudoku_board.h"

#include <array>
#include <filesystem>

struct SudokuSessionState
{
    bool paused = false;
    bool notesMode = false;
    int selectedCell = -1;
    std::array<int, SudokuBoard::cellCount> values{};
    std::array<int, SudokuBoard::cellCount> noteMasks{};
};

class SudokuSessionStore
{
public:
    explicit SudokuSessionStore(std::filesystem::path sessionPath = defaultSessionPath());

    bool load(SudokuSessionState &state) const;
    bool save(const SudokuSessionState &state) const;

    static std::filesystem::path defaultSessionPath();

private:
    std::filesystem::path sessionPath_;
};
