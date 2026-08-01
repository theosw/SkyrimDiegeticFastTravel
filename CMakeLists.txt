cmake_minimum_required(VERSION 3.24)

project(DNTParchmentPicker VERSION 0.1.0 LANGUAGES CXX)

option(DNT_PARCHMENT_BUILD_PLUGIN "Build the SKSE parchment-picker plugin" ON)
option(DNT_PARCHMENT_BUILD_TESTS "Build offline parchment-picker tests" ON)

add_library(DNTParchmentCore STATIC
    modules/parchment-picker/src/ParchmentCore.cpp
)
target_compile_features(DNTParchmentCore PUBLIC cxx_std_23)
target_include_directories(DNTParchmentCore PUBLIC
    modules/parchment-picker/include
)

if(DNT_PARCHMENT_BUILD_PLUGIN)
    set(BUILD_TESTS OFF CACHE BOOL "Disable CommonLibSSE tests" FORCE)
    set(ENABLE_SKYRIM_AE ON CACHE BOOL "Build for Skyrim AE" FORCE)
    set(ENABLE_SKYRIM_SE OFF CACHE BOOL "Do not build the SE variant" FORCE)
    set(ENABLE_SKYRIM_VR OFF CACHE BOOL "Do not build the VR variant" FORCE)

    set(
        DNT_COMMONLIBSSE_NG_DIR
        "C:/Users/Theo/Documents/SKSE Plugins/FrameGenTest/extern/CommonLibSSE-NG"
        CACHE PATH
        "Path to a CommonLibSSE-NG checkout"
    )
    if(NOT EXISTS "${DNT_COMMONLIBSSE_NG_DIR}/CMakeLists.txt")
        message(FATAL_ERROR
            "CommonLibSSE-NG was not found at '${DNT_COMMONLIBSSE_NG_DIR}'. "
            "Configure DNT_COMMONLIBSSE_NG_DIR with a valid checkout."
        )
    endif()

    add_subdirectory("${DNT_COMMONLIBSSE_NG_DIR}" CommonLibSSE EXCLUDE_FROM_ALL)
    if(NOT COMMAND add_commonlibsse_plugin)
        include("${DNT_COMMONLIBSSE_NG_DIR}/cmake/CommonLibSSE.cmake")
    endif()

    add_commonlibsse_plugin(DNTParchmentPicker
        NAME "DNT Parchment Picker"
        AUTHOR "Theo"
        SOURCES
            modules/parchment-picker/src/MenuFrameworkAPI.cpp
            modules/parchment-picker/src/Papyrus.cpp
            modules/parchment-picker/src/ParchmentMenu.cpp
            modules/parchment-picker/src/Plugin.cpp
    )
    target_compile_features(DNTParchmentPicker PRIVATE cxx_std_23)
    target_compile_options(DNTParchmentPicker PRIVATE /W4 /permissive- /Zc:preprocessor)
    target_precompile_headers(DNTParchmentPicker PRIVATE
        modules/parchment-picker/include/DNT/PCH.h
    )
    target_include_directories(DNTParchmentPicker PRIVATE
        modules/parchment-picker/include
    )
    target_link_libraries(DNTParchmentPicker PRIVATE DNTParchmentCore)

    add_custom_command(TARGET DNTParchmentPicker POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/modules/parchment-picker/mod/SKSE/Plugins"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "$<TARGET_FILE:DNTParchmentPicker>"
            "${CMAKE_CURRENT_SOURCE_DIR}/modules/parchment-picker/mod/SKSE/Plugins/$<TARGET_FILE_NAME:DNTParchmentPicker>"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "$<TARGET_PDB_FILE:DNTParchmentPicker>"
            "${CMAKE_CURRENT_SOURCE_DIR}/modules/parchment-picker/mod/SKSE/Plugins/$<TARGET_PDB_FILE_NAME:DNTParchmentPicker>"
        VERBATIM
    )
endif()

if(DNT_PARCHMENT_BUILD_TESTS)
    enable_testing()
    add_executable(DNTParchmentCoreTests
        modules/parchment-picker/tests/ParchmentCoreTests.cpp
    )
    target_compile_features(DNTParchmentCoreTests PRIVATE cxx_std_23)
    target_link_libraries(DNTParchmentCoreTests PRIVATE DNTParchmentCore)
    add_test(NAME DNTParchmentCoreTests COMMAND DNTParchmentCoreTests)
endif()
