cmake_minimum_required(VERSION 3.16)

project(remarkable_sudoku VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(BUILD_APP "Build the reMarkable app" ON)

add_library(sudoku_core
    src/game/sudoku_app_state_store.cpp
    src/game/sudoku_board.cpp
    src/game/sudoku_generator.cpp
    src/game/sudoku_session_store.cpp
    third_party/qqwing/src/cpp/qqwing.cpp
)

set_target_properties(sudoku_core PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

target_include_directories(sudoku_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_include_directories(sudoku_core PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/qqwing/src/cpp
)

include(CTest)

if(BUILD_TESTING)
    add_executable(sudoku_board_tests
        tests/sudoku_board_test.cpp
    )

    add_executable(sudoku_qml_contract_tests
        tests/sudoku_qml_contract_test.cpp
    )

    add_executable(sudoku_session_store_tests
        tests/sudoku_session_store_test.cpp
    )

    add_executable(sudoku_app_state_store_tests
        tests/sudoku_app_state_store_test.cpp
    )

    target_link_libraries(sudoku_board_tests PRIVATE sudoku_core)
    target_compile_definitions(sudoku_qml_contract_tests PRIVATE
        REMARKABLE_SUDOKU_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
    )
    target_link_libraries(sudoku_session_store_tests PRIVATE sudoku_core)
    target_link_libraries(sudoku_app_state_store_tests PRIVATE sudoku_core)

    add_test(NAME sudoku_board_tests COMMAND sudoku_board_tests)
    add_test(NAME sudoku_qml_contract_tests COMMAND sudoku_qml_contract_tests)
    add_test(NAME sudoku_session_store_tests COMMAND sudoku_session_store_tests)
    add_test(NAME sudoku_app_state_store_tests COMMAND sudoku_app_state_store_tests)
endif()

if(BUILD_APP)
    add_executable(remarkable_touch_injector
        src/tools/remarkable_touch_injector.cpp
    )

    find_package(Qt6 REQUIRED COMPONENTS Quick)

    qt_standard_project_setup(REQUIRES 6.5)
    qt_policy(SET QTP0004 NEW)

    qt_add_executable(remarkable_sudoku
        src/main.cpp
    )

    qt_add_qml_module(remarkable_sudoku
        URI RemarkableSudoku
        QML_FILES
            src/qml/Main.qml
            src/qml/SudokuAppView.qml
            src/qml/SudokuMenuView.qml
            src/qml/SudokuView.qml
        SOURCES
            src/app/sudoku_app_controller.cpp
            src/app/sudoku_app_controller.h
            src/game/sudoku_game.cpp
            src/game/sudoku_game.h
            src/input/tablet_mouse_bridge.cpp
            src/input/tablet_mouse_bridge.h
    )

    qt_add_resources(remarkable_sudoku remarkable_sudoku_assets
        PREFIX "/remarkable-sudoku/assets"
        FILES
            src/assets/title.png
    )

    set_source_files_properties(
        src/qml/SudokuAppView.qml
        PROPERTIES QT_RESOURCE_ALIAS "SudokuAppView.qml"
    )
    set_source_files_properties(
        src/qml/SudokuMenuView.qml
        PROPERTIES QT_RESOURCE_ALIAS "SudokuMenuView.qml"
    )
    set_source_files_properties(
        src/qml/SudokuView.qml
        PROPERTIES QT_RESOURCE_ALIAS "SudokuView.qml"
    )
    set_source_files_properties(
        xovi/qml/AppsDrawer.qml
        PROPERTIES QT_RESOURCE_ALIAS "AppsDrawer.qml"
    )
    set_source_files_properties(
        xovi/qml/SudokuPageHost.qml
        PROPERTIES QT_RESOURCE_ALIAS "SudokuPageHost.qml"
    )
    set_source_files_properties(
        xovi/qml/InkDebugAppView.qml
        PROPERTIES QT_RESOURCE_ALIAS "InkDebugAppView.qml"
    )

    add_library(remarkable_sudoku_xovi SHARED
        xovi/remarkable_sudoku_xovi.cpp
        src/app/sudoku_app_controller.cpp
        src/app/sudoku_app_controller.h
        src/debug/qml_object_inspector.cpp
        src/debug/qml_object_inspector.h
        src/game/sudoku_game.cpp
        src/game/sudoku_game.h
    )

    qt_add_resources(remarkable_sudoku_xovi remarkable_sudoku_xovi_resources
        PREFIX "/remarkable-sudoku/qml"
        FILES
            src/qml/SudokuAppView.qml
            src/qml/SudokuMenuView.qml
            src/qml/SudokuView.qml
            xovi/qml/AppsDrawer.qml
            xovi/qml/SudokuPageHost.qml
            xovi/qml/InkDebugAppView.qml
    )

    qt_add_resources(remarkable_sudoku_xovi remarkable_sudoku_xovi_assets
        PREFIX "/remarkable-sudoku/assets"
        FILES
            src/assets/title.png
    )

    target_include_directories(remarkable_sudoku PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/app
        ${CMAKE_CURRENT_SOURCE_DIR}/src/game
    )

    target_include_directories(remarkable_sudoku_xovi PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/app
        ${CMAKE_CURRENT_SOURCE_DIR}/src/game
    )

    target_link_libraries(remarkable_sudoku PRIVATE Qt6::Quick sudoku_core)
    target_link_libraries(remarkable_sudoku_xovi PRIVATE Qt6::Quick sudoku_core)

    set_target_properties(remarkable_sudoku_xovi PROPERTIES
        OUTPUT_NAME "remarkable-sudoku-xovi"
    )
endif()
