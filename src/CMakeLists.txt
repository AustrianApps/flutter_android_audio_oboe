# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(android_audio_oboe_library VERSION 0.0.1 LANGUAGES C CXX)

add_library(android_audio_oboe SHARED
        "android_audio_oboe.c"
        "oboe_player.cpp"
        "oboe_recorder.cpp"
)

set_target_properties(android_audio_oboe PROPERTIES
  PUBLIC_HEADER android_audio_oboe.h
  OUTPUT_NAME "android_audio_oboe"
)

target_compile_definitions(android_audio_oboe PUBLIC DART_SHARED_LIB)

if (ANDROID)
    # Support Android 15 16k page size
    target_link_options(android_audio_oboe PRIVATE "-Wl,-z,max-page-size=16384")
endif ()

find_package(oboe REQUIRED CONFIG)
target_link_libraries(
        android_audio_oboe
        oboe::oboe
        log
) # You may have other libraries here such as `log`.
