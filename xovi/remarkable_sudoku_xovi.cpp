#include "app/sudoku_app_controller.h"
#include "game/sudoku_game.h"

#include <QtQml/qqml.h>

#include <cstdio>
#include <dlfcn.h>

int qInitResources_remarkable_sudoku_xovi_resources();

namespace
{
void initializeResources()
{
    qInitResources_remarkable_sudoku_xovi_resources();
}
}

extern "C" void _xovi_construct()
{
    initializeResources();
    qmlRegisterType<SudokuAppController>("RemarkableSudoku", 1, 0, "SudokuAppController");
    qmlRegisterType<SudokuGame>("RemarkableSudoku", 1, 0, "SudokuGame");
}

extern "C" char _xovi_shouldLoad()
{
    void *resourceRegistrar = dlsym(RTLD_DEFAULT, "_Z21qRegisterResourceDataiPKhS0_S0_");
    if (resourceRegistrar == nullptr) {
        std::printf("[RemarkableSudokuXovi]: Not a GUI application. Refusing to load.\n");
        return 0;
    }

    return 1;
}

extern "C" __attribute__((section(".xovi_info"))) const int EXTENSIONVERSION = 0x00000100;
__attribute__((section(".xovi"))) const char *LINKTABLENAMES = "Ephony\0\0";
__attribute__((section(".xovi"))) const void *LINKTABLEVALUES[] = {(void *) 1, (void *) 0};
