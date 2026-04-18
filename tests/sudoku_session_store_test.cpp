#include "game/sudoku_board.h"
#include "game/sudoku_session_store.h"

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>

namespace
{
void expect(bool condition, const std::string &message)
{
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
        std::exit(1);
    }
}
}

int main()
{
    SudokuBoard board;
    auto values = board.currentValues();
    values[2] = 4;
    values[3] = 9;

    const auto tempDirectory = std::filesystem::temp_directory_path() / "remarkable-sudoku-session-store-test";
    const auto sessionPath = tempDirectory / "session-state.txt";

    std::filesystem::remove_all(tempDirectory);

    SudokuSessionStore store(sessionPath);
    SudokuSessionState savedState;
    savedState.paused = true;
    savedState.notesMode = true;
    savedState.selectedCell = 3;
    savedState.values = values;
    savedState.noteMasks[5] = (1 << 0) | (1 << 6);

    expect(store.save(savedState), "session store should save the current state");

    SudokuSessionState loadedState;
    expect(store.load(loadedState), "session store should load a saved state");
    expect(loadedState.paused, "loaded state should restore pause");
    expect(loadedState.notesMode, "loaded state should restore notes mode");
    expect(loadedState.selectedCell == 3, "loaded state should restore selected cell");
    expect(loadedState.values == values, "loaded state should restore board values");
    expect(loadedState.noteMasks == savedState.noteMasks, "loaded state should restore note masks");

    std::filesystem::remove_all(tempDirectory);
}
