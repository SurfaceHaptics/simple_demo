# On macOS, we:
#
# 1. Copy all Conan-managed shared libraries to ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
# 2. Point DYLD_LIBRARY_PATH to ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
#
# This lets the dynamic linker resolve shared libraries without modifying
# the test binaries or the libraries that the test binaries link against.

function (tanvas_tweak_dyld_library_path test)
    if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        set_property(TEST ${test} APPEND
            PROPERTY ENVIRONMENT DYLD_LIBRARY_PATH=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
            )
    endif ()
endfunction ()

