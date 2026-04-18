#include "game/sudoku_app_state_store.h"

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>

namespace
{
SudokuPuzzleData makePuzzle(SudokuDifficulty difficulty)
{
    SudokuPuzzleData puzzle;
    puzzle.difficulty = difficulty;
    puzzle.givens = {
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
    puzzle.solution = {
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
    return puzzle;
}

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
    const auto tempDirectory = std::filesystem::temp_directory_path() / "remarkable-sudoku-app-state-test";
    const auto statePath = tempDirectory / "app-state.txt";

    std::filesystem::remove_all(tempDirectory);

    SudokuAppStateStore store(statePath);
    SudokuAppState savedState;
    savedState.session.active = true;
    savedState.session.puzzle = makePuzzle(SudokuDifficulty::Hard);
    savedState.session.paused = true;
    savedState.session.elapsedSeconds = 34;
    savedState.session.notesMode = true;
    savedState.session.selectedCell = 12;
    savedState.session.mistakePenalty = 3;
    savedState.session.values = savedState.session.puzzle.givens;
    savedState.session.values[2] = 4;
    savedState.session.noteMasks[5] = (1 << 0) | (1 << 3);
    savedState.session.hintedCells[2] = 1;
    savedState.bestScores[static_cast<std::size_t>(SudokuDifficulty::Easy)] = 18;
    savedState.bestScores[static_cast<std::size_t>(SudokuDifficulty::Hard)] = 9;
    savedState.cachedPuzzles[static_cast<std::size_t>(SudokuDifficulty::Easy)] = makePuzzle(SudokuDifficulty::Easy);
    savedState.hasCachedPuzzle[static_cast<std::size_t>(SudokuDifficulty::Easy)] = true;
    savedState.cachedPuzzles[static_cast<std::size_t>(SudokuDifficulty::Extreme)] = makePuzzle(SudokuDifficulty::Extreme);
    savedState.hasCachedPuzzle[static_cast<std::size_t>(SudokuDifficulty::Extreme)] = true;

    expect(store.save(savedState), "app state store should save the current session and cache");

    SudokuAppState loadedState;
    expect(store.load(loadedState), "app state store should load a saved state");
    expect(loadedState.session.active, "loaded state should restore an active session");
    expect(loadedState.session.puzzle.difficulty == SudokuDifficulty::Hard, "loaded session should restore difficulty");
    expect(loadedState.session.paused, "loaded session should restore pause");
    expect(loadedState.session.elapsedSeconds == 34, "loaded session should restore played time");
    expect(loadedState.session.notesMode, "loaded session should restore notes mode");
    expect(loadedState.session.selectedCell == 12, "loaded session should restore selection");
    expect(loadedState.session.mistakePenalty == 3, "loaded session should restore mistake penalty");
    expect(loadedState.session.values == savedState.session.values, "loaded session should restore values");
    expect(loadedState.session.noteMasks == savedState.session.noteMasks, "loaded session should restore note masks");
    expect(loadedState.session.hintedCells == savedState.session.hintedCells, "loaded session should restore hinted cells");
    expect(loadedState.bestScores[static_cast<std::size_t>(SudokuDifficulty::Easy)] == 18,
           "loaded state should restore the easy best score");
    expect(loadedState.bestScores[static_cast<std::size_t>(SudokuDifficulty::Hard)] == 9,
           "loaded state should restore the hard best score");
    expect(loadedState.hasCachedPuzzle[static_cast<std::size_t>(SudokuDifficulty::Easy)], "loaded state should restore easy cache");
    expect(loadedState.cachedPuzzles[static_cast<std::size_t>(SudokuDifficulty::Easy)].difficulty == SudokuDifficulty::Easy,
           "loaded state should restore cached puzzle difficulty");
    expect(loadedState.hasCachedPuzzle[static_cast<std::size_t>(SudokuDifficulty::Extreme)], "loaded state should restore extreme cache");

    std::filesystem::remove_all(tempDirectory);
}
