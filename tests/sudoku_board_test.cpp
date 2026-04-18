#include "game/sudoku_board.h"
#include "game/sudoku_puzzle.h"

#include <cstdlib>
#include <iostream>
#include <string>

namespace
{
SudokuPuzzleData makeSamplePuzzle()
{
    SudokuPuzzleData puzzle;
    puzzle.difficulty = SudokuDifficulty::Medium;
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

SudokuPuzzleData makeAlternatePuzzle()
{
    SudokuPuzzleData puzzle;
    puzzle.difficulty = SudokuDifficulty::Hard;
    puzzle.givens = {
        0, 0, 0, 2, 6, 0, 7, 0, 1,
        6, 8, 0, 0, 7, 0, 0, 9, 0,
        1, 9, 0, 0, 0, 4, 5, 0, 0,
        8, 2, 0, 1, 0, 0, 0, 4, 0,
        0, 0, 4, 6, 0, 2, 9, 0, 0,
        0, 5, 0, 0, 0, 3, 0, 2, 8,
        0, 0, 9, 3, 0, 0, 0, 7, 4,
        0, 4, 0, 0, 5, 0, 0, 3, 6,
        7, 0, 3, 0, 1, 8, 0, 0, 0,
    };
    puzzle.solution = {
        4, 3, 5, 2, 6, 9, 7, 8, 1,
        6, 8, 2, 5, 7, 1, 4, 9, 3,
        1, 9, 7, 8, 3, 4, 5, 6, 2,
        8, 2, 6, 1, 9, 5, 3, 4, 7,
        3, 7, 4, 6, 8, 2, 9, 1, 5,
        9, 5, 1, 7, 4, 3, 6, 2, 8,
        5, 1, 9, 3, 2, 6, 8, 7, 4,
        2, 4, 8, 9, 5, 7, 1, 3, 6,
        7, 6, 3, 4, 1, 8, 2, 5, 9,
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
    SudokuBoard board;
    expect(board.loadPuzzle(makeSamplePuzzle()), "board should load a dynamic puzzle");
    const int givenCellCount = board.filledCells();

    expect(board.valueAt(0) == 5, "first given cell should match the puzzle");
    expect(board.isGiven(0), "first cell should be marked as given");
    expect(!board.isEditable(0), "given cell should not be editable");
    expect(board.score() == 0, "new puzzle should start with zero score");

    expect(board.valueAt(2) == 0, "third cell should start empty");
    expect(board.isEditable(2), "third cell should be editable");
    expect(board.noteMaskAt(2) == 0, "editable cells should start without notes");
    int hintedCell = -1;
    expect(board.applyHint(0, &hintedCell), "board should hint a random editable cell when the preferred cell is invalid");
    expect(hintedCell >= 0 && board.isEditable(hintedCell), "random hint should target an editable cell");
    expect(board.valueAt(hintedCell) == board.solution()[hintedCell], "random hint should fill the correct value");
    expect(board.score() == 0, "random hint should not increase the score");

    expect(board.loadPuzzle(makeSamplePuzzle()), "reloading should restore the original puzzle for the targeted hint check");
    expect(board.toggleNote(2, 4), "empty editable cells should accept notes");
    expect(board.noteMaskAt(2) == (1 << 3), "note mask should track the entered note");
    expect(board.toggleNote(2, 7), "cells should support multiple notes");
    expect(board.noteMaskAt(2) == ((1 << 3) | (1 << 6)), "note mask should combine digits");
    expect(board.toggleNote(2, 4), "entering the same note again should toggle it off");
    expect(board.noteMaskAt(2) == (1 << 6), "toggling a note should remove it");
    hintedCell = -1;
    expect(board.applyHint(2, &hintedCell), "board should hint the preferred editable cell");
    expect(hintedCell == 2, "targeted hint should keep the preferred cell");
    expect(board.valueAt(2) == 4, "editable cell should store the entered value");
    expect(board.isCorrect(2), "correct entry should be marked as correct");
    expect(board.score() == 0, "hinted cells should not count toward the score");
    expect(board.noteMaskAt(2) == 0, "hinting a value should clear notes on that cell");

    expect(!board.setValue(0, 9), "given cell should reject edits");
    expect(board.valueAt(0) == 5, "given cell should keep its original value");
    expect(!board.toggleNote(0, 2), "given cells should reject notes");

    expect(board.setValue(3, 9), "editable cell should accept an incorrect value");
    expect(board.valueAt(3) == 9, "incorrect entry should still be stored");
    expect(!board.isCorrect(3), "incorrect entry should be marked as incorrect");
    expect(board.mistakeCount() == 1, "board should count one incorrect entry");
    expect(board.mistakePenalty() == 1, "board should count a permanent mistake penalty");
    expect(board.score() == 0, "incorrect entries should not increase score");
    expect(!board.toggleNote(3, 2), "filled cells should reject notes");

    expect(board.clearValue(3), "editable cell should clear");
    expect(board.valueAt(3) == 0, "cleared cell should become empty again");
    expect(board.score() == 0, "clearing an incorrect entry should keep the penalty");

    expect(board.toggleNote(3, 2), "cleared editable cells should accept notes again");
    expect(board.noteMaskAt(3) == (1 << 1), "cleared cells should keep new notes");
    expect(board.clearEntry(3), "clear entry should clear notes when there is no value");
    expect(board.noteMaskAt(3) == 0, "clear entry should remove notes");

    expect(board.clearValue(2), "editable cell should clear");
    expect(board.score() == 0, "clearing a correct entry should lower the score");

    expect(board.setValue(3, 6), "editable cell should accept the correct value");
    expect(board.score() == 0, "a correct cell should still be offset by the earlier mistake penalty");

    expect(board.setValue(6, 9), "another editable cell should accept the correct value");
    expect(board.score() == 1, "multiple correct manual cells should outpace the mistake penalty");

    auto restoredValues = board.currentValues();
    restoredValues[2] = 4;
    restoredValues[3] = 9;
    expect(board.restoreValues(restoredValues), "board should restore editable cell values");
    expect(board.valueAt(2) == 4, "restore should apply correct editable values");
    expect(board.valueAt(3) == 9, "restore should apply incorrect editable values");

    auto restoredNotes = board.currentNotes();
    restoredNotes[5] = (1 << 0) | (1 << 8);
    expect(board.clearValue(3), "filled editable cells should clear before note restore checks");
    expect(board.restoreNotes(restoredNotes), "board should restore note masks");
    expect(board.noteMaskAt(5) == ((1 << 0) | (1 << 8)), "restore should apply note masks");

    auto restoredHints = board.currentHintedCells();
    restoredHints[2] = 1;
    expect(board.restoreHintedCells(restoredHints), "board should restore hinted cell markers");
    board.setMistakePenalty(2);
    expect(board.mistakePenalty() == 2, "board should restore permanent mistake penalties");

    auto invalidValues = restoredValues;
    invalidValues[0] = 1;
    expect(!board.restoreValues(invalidValues), "restore should reject changes to given cells");

    auto invalidNotes = restoredNotes;
    invalidNotes[0] = 1 << 2;
    expect(!board.restoreNotes(invalidNotes), "restore should reject notes on given cells");

    expect(board.loadPuzzle(makeAlternatePuzzle()), "board should switch to a different puzzle");
    const int alternateGivenCellCount = board.filledCells();
    expect(board.valueAt(0) == 0, "loading a new puzzle should replace previous givens");
    expect(board.valueAt(3) == 2, "loading a new puzzle should expose the new givens");
    expect(board.noteMaskAt(5) == 0, "loading a new puzzle should clear previous notes");
    expect(board.score() == 0, "loading a new puzzle should reset score");

    board.fillWithSolution();

    expect(!board.applyHint(2, &hintedCell), "solved boards should not provide hints");

    expect(board.isSolved(), "filled solution should mark the puzzle as solved");
    expect(board.filledCells() == SudokuBoard::cellCount, "solved puzzle should fill every cell");
    expect(board.mistakeCount() == 0, "solved puzzle should have no mistakes");
    expect(board.mistakePenalty() == 0, "filling the solution should reset the permanent mistake penalty");
    expect(board.score() == SudokuBoard::cellCount - alternateGivenCellCount,
           "solved puzzle score should equal the number of editable cells");
    expect(board.noteMaskAt(5) == 0, "filling the solution should clear notes");
}
