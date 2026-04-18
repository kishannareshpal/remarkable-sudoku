#include "game/sudoku_session_store.h"

#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <system_error>
#include <utility>

namespace
{
constexpr int kCurrentVersion = 2;

std::string serializeArray(const std::array<int, SudokuBoard::cellCount> &values)
{
    std::ostringstream stream;

    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index > 0) {
            stream << ',';
        }

        stream << values[index];
    }

    return stream.str();
}

bool parseArray(
    const std::string &serializedValues,
    int maxValue,
    std::array<int, SudokuBoard::cellCount> &values)
{
    std::istringstream stream(serializedValues);
    std::string token;
    std::size_t index = 0;

    while (std::getline(stream, token, ',')) {
        if (index >= values.size()) {
            return false;
        }

        std::istringstream tokenStream(token);
        int value = -1;
        tokenStream >> value;
        if (!tokenStream || !tokenStream.eof() || value < 0 || value > maxValue) {
            return false;
        }

        values[index] = value;
        ++index;
    }

    return index == values.size();
}

bool parseVersion(const std::string &line, int &version)
{
    if (line.rfind("version=", 0) != 0) {
        return false;
    }

    std::istringstream stream(line.substr(8));
    stream >> version;
    return stream && stream.eof() && version >= 1 && version <= kCurrentVersion;
}
}

SudokuSessionStore::SudokuSessionStore(std::filesystem::path sessionPath)
    : sessionPath_(std::move(sessionPath))
{
}

bool SudokuSessionStore::load(SudokuSessionState &state) const
{
    std::ifstream input(sessionPath_);
    if (!input.is_open()) {
        return false;
    }

    SudokuSessionState loadedState;
    int version = 0;
    bool sawVersion = false;
    bool sawPaused = false;
    bool sawNotesMode = false;
    bool sawSelectedCell = false;
    bool sawValues = false;
    bool sawNoteMasks = false;
    std::string line;

    while (std::getline(input, line)) {
        if (parseVersion(line, version)) {
            sawVersion = true;
            continue;
        }

        if (line.rfind("paused=", 0) == 0) {
            const auto pausedValue = line.substr(7);
            if (pausedValue == "1") {
                loadedState.paused = true;
            } else if (pausedValue == "0") {
                loadedState.paused = false;
            } else {
                return false;
            }

            sawPaused = true;
            continue;
        }

        if (line.rfind("notesMode=", 0) == 0) {
            const auto notesModeValue = line.substr(10);
            if (notesModeValue == "1") {
                loadedState.notesMode = true;
            } else if (notesModeValue == "0") {
                loadedState.notesMode = false;
            } else {
                return false;
            }

            sawNotesMode = true;
            continue;
        }

        if (line.rfind("selectedCell=", 0) == 0) {
            std::istringstream stream(line.substr(13));
            int selectedCell = -2;
            stream >> selectedCell;
            if (!stream || !stream.eof() || selectedCell < -1 || selectedCell >= SudokuBoard::cellCount) {
                return false;
            }

            loadedState.selectedCell = selectedCell;
            sawSelectedCell = true;
            continue;
        }

        if (line.rfind("values=", 0) == 0) {
            if (!parseArray(line.substr(7), SudokuBoard::rowLength, loadedState.values)) {
                return false;
            }

            sawValues = true;
            continue;
        }

        if (line.rfind("noteMasks=", 0) == 0) {
            if (!parseArray(line.substr(10), (1 << SudokuBoard::rowLength) - 1, loadedState.noteMasks)) {
                return false;
            }

            sawNoteMasks = true;
            continue;
        }

        return false;
    }

    if (!sawVersion || !sawPaused || !sawSelectedCell || !sawValues) {
        return false;
    }

    if (version >= 2 && (!sawNotesMode || !sawNoteMasks)) {
        return false;
    }

    state = loadedState;
    return true;
}

bool SudokuSessionStore::save(const SudokuSessionState &state) const
{
    std::error_code error;
    std::filesystem::create_directories(sessionPath_.parent_path(), error);
    if (error) {
        return false;
    }

    const auto temporaryPath = sessionPath_.string() + ".tmp";
    std::ofstream output(temporaryPath, std::ios::trunc);
    if (!output.is_open()) {
        return false;
    }

    output << "version=" << kCurrentVersion << '\n';
    output << "paused=" << (state.paused ? '1' : '0') << '\n';
    output << "notesMode=" << (state.notesMode ? '1' : '0') << '\n';
    output << "selectedCell=" << state.selectedCell << '\n';
    output << "values=" << serializeArray(state.values) << '\n';
    output << "noteMasks=" << serializeArray(state.noteMasks) << '\n';
    output.close();

    if (!output) {
        std::filesystem::remove(temporaryPath, error);
        return false;
    }

    std::filesystem::rename(temporaryPath, sessionPath_, error);
    if (!error) {
        return true;
    }

    std::filesystem::remove(sessionPath_, error);
    error.clear();
    std::filesystem::rename(temporaryPath, sessionPath_, error);
    if (error) {
        std::filesystem::remove(temporaryPath, error);
        return false;
    }

    return true;
}

std::filesystem::path SudokuSessionStore::defaultSessionPath()
{
    if (const char *overridePath = std::getenv("RM2_SUDOKU_STATE_FILE")) {
        if (*overridePath != '\0') {
            return overridePath;
        }
    }

    if (const char *home = std::getenv("HOME")) {
        if (*home != '\0') {
            return std::filesystem::path(home) / ".local/share/remarkable-sudoku/session-state.txt";
        }
    }

    return std::filesystem::temp_directory_path() / "remarkable-sudoku/session-state.txt";
}
