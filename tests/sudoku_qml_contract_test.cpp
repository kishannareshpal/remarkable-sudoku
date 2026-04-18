#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
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

std::string readFile(const std::filesystem::path &path)
{
    std::ifstream input(path);
    expect(input.is_open(), "expected to open " + path.string());

    std::ostringstream buffer;
    buffer << input.rdbuf();
    return buffer.str();
}
}

int main()
{
    const std::filesystem::path sourceRoot = REMARKABLE_SUDOKU_SOURCE_DIR;
    const std::string sudokuAppView = readFile(sourceRoot / "src/qml/SudokuAppView.qml");
    const std::string sudokuView = readFile(sourceRoot / "src/qml/SudokuView.qml");

    expect(sudokuAppView.find("sudokuView.handleScenePress(scenePosition)") != std::string::npos,
           "SudokuAppView should forward scene presses into SudokuView");
    expect(sudokuView.find("function handleScenePress(scenePosition)") != std::string::npos,
           "SudokuView should define handleScenePress for pen-driven button presses");
    expect(sudokuView.find("id: pauseButton") != std::string::npos,
           "SudokuView should keep a dedicated pause button in the header");
    expect(sudokuView.find("visible: !game.solved") != std::string::npos,
           "SudokuView should hide gameplay-only controls when the puzzle is solved");
}
