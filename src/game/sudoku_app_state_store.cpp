#include "game/sudoku_app_state_store.h"

#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <system_error>
#include <utility>

namespace
{
constexpr int kCurrentVersion = 3;
constexpr int kMaxNoteMask = (1 << 9) - 1;

std::string serializeArray(const std::array<int, SudokuPuzzleData::cellCount> &values)
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
    std::array<int, SudokuPuzzleData::cellCount> &values)
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

bool parseBooleanValue(const std::string &value, bool &parsed)
{
    if (value == "1") {
        parsed = true;
        return true;
    }

    if (value == "0") {
        parsed = false;
        return true;
    }

    return false;
}

bool parseIntValue(const std::string &value, int minValue, int maxValue, int &parsed)
{
    std::istringstream stream(value);
    stream >> parsed;
    return stream && stream.eof() && parsed >= minValue && parsed <= maxValue;
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

bool assignSessionField(SudokuGameSessionState &session, const std::string &key, const std::string &value)
{
    if (key == "session.active") {
        return parseBooleanValue(value, session.active);
    }

    if (key == "session.difficulty") {
        return sudokuDifficultyFromString(value, session.puzzle.difficulty);
    }

    if (key == "session.givens") {
        return parseArray(value, 9, session.puzzle.givens);
    }

    if (key == "session.solution") {
        return parseArray(value, 9, session.puzzle.solution);
    }

    if (key == "session.paused") {
        return parseBooleanValue(value, session.paused);
    }

    if (key == "session.elapsedSeconds") {
        return parseIntValue(value, 0, 7 * 24 * 60 * 60, session.elapsedSeconds);
    }

    if (key == "session.notesMode") {
        return parseBooleanValue(value, session.notesMode);
    }

    if (key == "session.selectedCell") {
        return parseIntValue(value, -1, SudokuPuzzleData::cellCount - 1, session.selectedCell);
    }

    if (key == "session.mistakePenalty") {
        return parseIntValue(value, 0, SudokuPuzzleData::cellCount * 9, session.mistakePenalty);
    }

    if (key == "session.values") {
        return parseArray(value, 9, session.values);
    }

    if (key == "session.noteMasks") {
        return parseArray(value, kMaxNoteMask, session.noteMasks);
    }

    if (key == "session.hintedCells") {
        return parseArray(value, 1, session.hintedCells);
    }

    return false;
}

bool assignBestScoreField(SudokuAppState &state, SudokuDifficulty difficulty, const std::string &value)
{
    int bestScore = 0;
    if (!parseIntValue(value, 0, SudokuPuzzleData::cellCount, bestScore)) {
        return false;
    }

    state.bestScores[static_cast<std::size_t>(difficulty)] = bestScore;
    return true;
}

bool assignCacheField(SudokuAppState &state, SudokuDifficulty difficulty, const std::string &field, const std::string &value)
{
    const auto index = static_cast<std::size_t>(difficulty);

    if (field == "present") {
        return parseBooleanValue(value, state.hasCachedPuzzle[index]);
    }

    if (field == "difficulty") {
        return sudokuDifficultyFromString(value, state.cachedPuzzles[index].difficulty);
    }

    if (field == "givens") {
        return parseArray(value, 9, state.cachedPuzzles[index].givens);
    }

    if (field == "solution") {
        return parseArray(value, 9, state.cachedPuzzles[index].solution);
    }

    return false;
}

void writePuzzle(std::ofstream &output, const std::string &prefix, const SudokuPuzzleData &puzzle)
{
    output << prefix << ".difficulty=" << sudokuDifficultyId(puzzle.difficulty) << '\n';
    output << prefix << ".givens=" << serializeArray(puzzle.givens) << '\n';
    output << prefix << ".solution=" << serializeArray(puzzle.solution) << '\n';
}
}

SudokuAppStateStore::SudokuAppStateStore(std::filesystem::path statePath)
    : statePath_(std::move(statePath))
{
}

bool SudokuAppStateStore::load(SudokuAppState &state) const
{
    std::ifstream input(statePath_);
    if (!input.is_open()) {
        return false;
    }

    SudokuAppState loadedState;
    int version = 0;
    bool sawVersion = false;
    std::string line;

    while (std::getline(input, line)) {
        const auto separatorIndex = line.find('=');
        if (separatorIndex == std::string::npos) {
            return false;
        }

        if (parseVersion(line, version)) {
            sawVersion = true;
            continue;
        }

        const std::string key = line.substr(0, separatorIndex);
        const std::string value = line.substr(separatorIndex + 1);

        if (key.rfind("session.", 0) == 0) {
            if (!assignSessionField(loadedState.session, key, value)) {
                return false;
            }
            continue;
        }

        if (key.rfind("cache.", 0) == 0) {
            const auto difficultyStart = 6U;
            const auto fieldSeparator = key.find('.', difficultyStart);
            if (fieldSeparator == std::string::npos) {
                return false;
            }

            SudokuDifficulty difficulty;
            if (!sudokuDifficultyFromString(std::string_view(key).substr(difficultyStart, fieldSeparator - difficultyStart), difficulty)) {
                return false;
            }

            if (!assignCacheField(loadedState, difficulty, key.substr(fieldSeparator + 1), value)) {
                return false;
            }
            continue;
        }

        if (key.rfind("bestScore.", 0) == 0) {
            SudokuDifficulty difficulty;
            if (!sudokuDifficultyFromString(std::string_view(key).substr(10), difficulty)) {
                return false;
            }

            if (!assignBestScoreField(loadedState, difficulty, value)) {
                return false;
            }
            continue;
        }

        return false;
    }

    if (!sawVersion) {
        return false;
    }

    state = loadedState;
    return true;
}

bool SudokuAppStateStore::save(const SudokuAppState &state) const
{
    std::error_code error;
    std::filesystem::create_directories(statePath_.parent_path(), error);
    if (error) {
        return false;
    }

    const auto temporaryPath = statePath_.string() + ".tmp";
    std::ofstream output(temporaryPath, std::ios::trunc);
    if (!output.is_open()) {
        return false;
    }

    output << "version=" << kCurrentVersion << '\n';
    output << "session.active=" << (state.session.active ? '1' : '0') << '\n';
    writePuzzle(output, "session", state.session.puzzle);
    output << "session.paused=" << (state.session.paused ? '1' : '0') << '\n';
    output << "session.elapsedSeconds=" << state.session.elapsedSeconds << '\n';
    output << "session.notesMode=" << (state.session.notesMode ? '1' : '0') << '\n';
    output << "session.selectedCell=" << state.session.selectedCell << '\n';
    output << "session.mistakePenalty=" << state.session.mistakePenalty << '\n';
    output << "session.values=" << serializeArray(state.session.values) << '\n';
    output << "session.noteMasks=" << serializeArray(state.session.noteMasks) << '\n';
    output << "session.hintedCells=" << serializeArray(state.session.hintedCells) << '\n';

    for (SudokuDifficulty difficulty : kSudokuDifficulties) {
        output << "bestScore." << sudokuDifficultyId(difficulty) << '='
               << state.bestScores[static_cast<std::size_t>(difficulty)] << '\n';
    }

    for (SudokuDifficulty difficulty : kSudokuDifficulties) {
        const auto index = static_cast<std::size_t>(difficulty);
        const std::string prefix = std::string("cache.") + sudokuDifficultyId(difficulty);
        output << prefix << ".present=" << (state.hasCachedPuzzle[index] ? '1' : '0') << '\n';
        writePuzzle(output, prefix, state.cachedPuzzles[index]);
    }

    output.close();
    if (!output) {
        std::filesystem::remove(temporaryPath, error);
        return false;
    }

    std::filesystem::rename(temporaryPath, statePath_, error);
    if (!error) {
        return true;
    }

    std::filesystem::remove(statePath_, error);
    error.clear();
    std::filesystem::rename(temporaryPath, statePath_, error);
    if (error) {
        std::filesystem::remove(temporaryPath, error);
        return false;
    }

    return true;
}

std::filesystem::path SudokuAppStateStore::defaultStatePath()
{
    if (const char *overridePath = std::getenv("RM2_SUDOKU_APP_STATE_FILE")) {
        if (*overridePath != '\0') {
            return overridePath;
        }
    }

    if (const char *home = std::getenv("HOME")) {
        if (*home != '\0') {
            return std::filesystem::path(home) / ".local/share/remarkable-sudoku/app-state.txt";
        }
    }

    return std::filesystem::temp_directory_path() / "remarkable-sudoku/app-state.txt";
}
