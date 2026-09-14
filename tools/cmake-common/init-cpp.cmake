# init-cpp.cmake uses directives introduced in CMake 3.13
cmake_minimum_required(VERSION 3.13.0)

# This file contains settings meant to apply to all targets.  Include it before
# defining any targets.

option(TANVAS_ASAN "Enable AddressSanitizer" OFF)
option(TANVAS_CLANG_TIDY "Run clang-tidy if available" OFF)
option(TANVAS_TEST "Build engine with test hooks and tests" OFF)
option(TANVAS_TSAN "Enable ThreadSanitizer (cannot be used with ASan or UBSan)" OFF)
option(TANVAS_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)
option(TANVAS_LIBFUZZER "Enable libfuzzer instrumentation" OFF)
option(TANVAS_COVERAGE "Enable code coverage" OFF)
option(TANVAS_USE_LIBCPP "Use libc++" OFF)

# On Linux, it can be very tricky to get clang to use libc++.  Ubuntu
# provides a clang-libc++ wrapper for this, but that wrapper isn't present
# if you install clang from apt.llvm.org, which you may want to do for
# newer clang and libc++.
#
# To get around this, we provide a hack that sets -stdlib=libc++.  It must run
# before conan_cmake_run because conan_cmake_run will analyze compile options
# to determine whether to use libc++ or libstdc++.
#
# If you have access to Ubuntu's clang-libc++ wrapper or have written one
# yourself, just use that and feel free to forget that this option exists.
if (TANVAS_USE_LIBCPP)
    add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-stdlib=libc++>)
    add_link_options($<$<COMPILE_LANGUAGE:CXX>:-stdlib=libc++>)
endif ()

# Use Tanvas Conan remotes (ver, qttanvastouch, etc.). OFF = build with Conan Center only (no Tanvas remotes).
if (NOT DEFINED TANVAS_CONAN_REMOTES)
    set(TANVAS_CONAN_REMOTES OFF CACHE BOOL "Use Tanvas Conan remotes (ver, qttanvastouch). OFF = Conan Center only.")
endif ()
# If we're running cmake from conan create, use the Conan-generated data from
# conan create.  Otherwise, run Conan if necessary.
if (CONAN_EXPORTED)
    include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
    conan_basic_setup(TARGETS)
else ()
    include(cmake-conan/conan)
    # Normalize profile path to forward slashes so CMake/parse_arguments do not treat backslashes as escapes
    set(_conan_profile "${TANVAS_CONAN_PROFILE}")
    string(REPLACE "\\" "/" _conan_profile "${_conan_profile}")
    if (TANVAS_CONAN_REMOTES)
        set(_conan_opts "use_tanvas_remotes=True")
    else ()
        # qt:with_freetype=False avoids LNK2019. qt:with_libpng=False + patch = Qt bundled libpng (PNG support).
        # qt:opengl=desktop avoids building ANGLE (which needs flex/bison); uses system OpenGL instead.
        set(_conan_opts "use_tanvas_remotes=False" "qt:with_freetype=False" "qt:with_libpng=False" "qt:opengl=desktop")
    endif ()
    conan_cmake_run(CONANFILE conanfile.py
            BASIC_SETUP CMAKE_TARGETS
            INSTALL_FOLDER ${CMAKE_BINARY_DIR}
            ARCH ${TANVAS_ARCH}
            PROFILE "${_conan_profile}"
            PROFILE_AUTO ALL
            BUILD missing
            OPTIONS ${_conan_opts}
            )
endif ()

# This macro is adapted from Conan's CMake generator output, which is made
# available under the terms of the MIT License:
#
# https://github.com/conan-io/conan/blob/6b903077779ac7c8782e907b324eed373d44b1f2/conans/client/generators/cmake_common.py#L311-L321a
# https://web.archive.org/web/20190721022549/https://github.com/conan-io/conan/blob/6b903077779ac7c8782e907b324eed373d44b1f2/conans/client/generators/cmake_common.py
macro(tanvas_split_version VERSION_STRING MAJOR MINOR PATCH)
    #make a list from the version string
    string(REPLACE "." ";" VERSION_LIST "${VERSION_STRING}")

    #write output values
    list(LENGTH VERSION_LIST _version_len)
    list(GET VERSION_LIST 0 ${MAJOR})
    if (${_version_len} GREATER 1)
        list(GET VERSION_LIST 1 ${MINOR})
    endif ()

    if (${_version_len} GREATER 2)
        list(GET VERSION_LIST 2 ${PATCH})
    endif ()
endmacro()

# Set TANVAS_{MAJOR, MINOR, PATCH}_VERSION from CONAN_PACKAGE_VERSION
tanvas_split_version("${CONAN_PACKAGE_VERSION}"
        TANVAS_MAJOR_VERSION
        TANVAS_MINOR_VERSION
        TANVAS_PATCH_VERSION
        )

# Use C++17, C90 (for MSVC), disable vendor extensions
set(CMAKE_C_STANDARD 90)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)

# All symbols are hidden unless explicitly made visible
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

# Yes, all symbols default to hidden, including things like template
# instantiations
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Where applicable, build as PIC
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Use maximum-ish warning levels
if (MSVC)
    # Remove /W3 from CMAKE_CXX_FLAGS, which is provided by default
    # installations of Visual Studio's CMake Tools
    string(REGEX REPLACE "/W[0-4]" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    string(REGEX REPLACE "/W[0-4]" "" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")

    # Enable level 4 warnings (i.e. all warnings that aren't off by default),
    # disable permissive mode, and use UTF-8 for source and execution character
    # set
    add_compile_options(/W4 /permissive- /utf-8)

    # Turn on MSVC's new preprocessor
    # (https://devblogs.microsoft.com/cppblog/msvc-preprocessor-progress-towards-conformance/)
    # This is also needed by range-v3
    add_compile_options(/experimental:preprocessor)
else ()
    add_compile_options(-Wall -Wextra)
endif ()

# C++ errors end up a lot more useful if you stop on the first error.
# If you don't, then the erroneous construct cascades into code down the line,
# which often yields a bunch of nonsense error messages.
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wfatal-errors)
endif ()

# GCC 5 introduced a bug in their implementation of the ARM procedure call that
# was fixed in GCC 7.  The bug required an ABI change, so GCC will warn about
# that.  However, we use the same version of GCC across all libraries and
# builds, so this break does not affect us.  Therefore, the warning is noise.
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    add_compile_options(-Wno-psabi)
endif ()

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

# Configure sanitizers
set(TANVAS_SANITIZERS)
if (TANVAS_ASAN)
    message(STATUS "Using AddressSanitizer")
    list(APPEND TANVAS_SANITIZERS "address")
endif ()

if (TANVAS_UBSAN)
    message(STATUS "Using UndefinedBehaviorSanitizer")
    list(APPEND TANVAS_SANITIZERS "undefined")
endif ()

if (TANVAS_LIBFUZZER)
    message(STATUS "Using libfuzzer")

    # There are two fuzzer sanitizers: "fuzzer" and "fuzzer-no-link".  The former
    # contains libfuzzer's main(), which we don't want to link into modules
    # that already have a main(), e.g. the MVP and all the examples.
    #
    # Because there are fewer fuzzer targets than other modules, this enables the
    # "fuzzer-no-link" sanitizer, which instruments code for fuzzing but does not
    # drag in libfuzzer's main().  The tanvas_enable_libfuzzer_link function
    # (see below) must be used on fuzzer driver targets.
    list(APPEND TANVAS_SANITIZERS "fuzzer-no-link")
endif ()

if (TANVAS_TSAN)
    if (TANVAS_TSAN AND TANVAS_ASAN)
        message(FATAL_ERROR "ThreadSanitizer and AddressSanitizer cannot be simultaneously enabled")
    endif ()

    message(STATUS "Using ThreadSanitizer")
    list(APPEND TANVAS_SANITIZERS "thread")
endif ()

string(REPLACE ";" "," _sanitize_list "${TANVAS_SANITIZERS}")

if (_sanitize_list)
    add_compile_options("-fsanitize=${_sanitize_list}")
    add_compile_options(-g -fno-omit-frame-pointer)
    add_link_options("-fsanitize=${_sanitize_list}")
endif ()

# Enable code coverage.
#
# For clang, we use source instrumentation (see
# https://clang.llvm.org/docs/SourceBasedCodeCoverage.html for details).  This
# can be used with libfuzzer and the other sanitizers.
#
# For gcc, we use the --coverage flag; see
# https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html for details.
# We also encode absolute paths to source files, which is recommended to assist
# report generators when doing out-of-tree builds.  (All builds default to
# out-of-tree.)
#
# Other compilers are not yet supported.
if (TANVAS_COVERAGE)
    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        message(STATUS "Using code coverage for clang")
        add_compile_options(-fprofile-instr-generate -fcoverage-mapping)
        add_link_options(-fprofile-instr-generate -fcoverage-mapping)
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        message(STATUS "Using code coverage for gcc")
        add_compile_options(--coverage -fprofile-abs-path)
        add_link_options(--coverage)
    else()
        message(FATAL_ERROR "Don't know how to enable code coverage for compiler ${CMAKE_CXX_COMPILER_ID}")
    endif()
endif()

# Configure clang-tidy and run it on all subsequently defined C and C++ targets.
# To opt-out of clang-tidy for a target, set its CXX_CLANG_TIDY (or
# C_CLANG_TIDY for C targets) property to "".
if (TANVAS_CLANG_TIDY)
    find_program(CLANG_TIDY NAMES clang-tidy clang-tidy-8)

    if (NOT TANVAS_CLANG_TIDY_CHECKS)
        set(TANVAS_CLANG_TIDY_CHECKS
                "-*"               # disable all defaults
                "boost*"           # enable Boost recommendations
                "clang-analyzer*"  # enable clang-analyzer checks
                "modernize*"       # make C++11+ modernization recommendations
                "bugprone*"        # look for bug-prone constructs
                "performance*"     # make performance recommendations

                # __FUNCTION__ occurs in the expansion of TLOG* macros, which may be used
                # in lambdas, and that is what it is
                "-bugprone-lambda-function-name"
                )
    endif ()

    if (NOT CLANG_TIDY)
        message(WARNING "clang-tidy not found")
    else ()
        message(STATUS "Using clang-tidy: ${CLANG_TIDY}")
        string(REPLACE ";" "," _comma_sep_checks "${TANVAS_CLANG_TIDY_CHECKS}")
        set(CLANG_TIDY_RUN "${CLANG_TIDY}" "-checks=${_comma_sep_checks}")
        set(CMAKE_C_CLANG_TIDY "${CLANG_TIDY_RUN}")
        set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_RUN}")
    endif ()
endif ()

# Switches the link-time sanitizer options on a target to "fuzzer" from
# "fuzzer-no-link".  Other sanitizer options are preserved, so e.g.
# -fsanitize=address,fuzzer-no-link will become -fsanitize=address,fuzzer.  This
# allows sanitizers to be used in libfuzzer runs.
#
# Use as follows:
#
#     add_executable(fuzzer-driver SOURCE FILES...)
#     tanvas_enable_fuzzer_link(fuzzer-driver)
#
# If TANVAS_LIBFUZZER is OFF or false, does nothing.
#
# If TANVAS_LIBFUZZER is ON or true and "fuzzer-no-link" is not present in an
# -fsanitize= argument, this function raises an error.
function(tanvas_enable_libfuzzer_link target)
    if (NOT TANVAS_LIBFUZZER)
        return()
    endif()

    string(REPLACE ";" "," _sanitize_list "${TANVAS_SANITIZERS}")
    string(REPLACE "fuzzer-no-link" "fuzzer" _sanitize_list "${_sanitize_list}")

    target_link_options(${target} PRIVATE "-fsanitize=${_sanitize_list}")
endfunction()

# In RelWithDebInfo on MSVC, CMake will add /debug to the linker flags.  When
# using the Microsoft linker, this disables elimination of unreferenced
# functions and data (i.e. implies /OPT:NOREF).
#
# In shared libraries and executables, unreferenced functions and data may
# stick around due to inclusion of static libraries with no LTO information
# or usage of header-only libraries that generate or drag in a large amount of
# code.  In cases like this, we do want the compiler to eliminate unreferenced
# functions and data.  This function re-enables this linker optimization for a
# given target iff building in RelWithDebInfo.
function (tanvas_msvc_enable_linker_optimizations target)
	if (CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo" AND MSVC)
		# TODO(yipdw): Investigate the effects of also turning on ICF:
		# https://docs.microsoft.com/en-us/cpp/build/reference/opt-optimizations?view=vs-2019
		message(STATUS "Enabling linker optimizations for target ${target}")
		target_link_options(${target} PRIVATE /OPT:REF)
	endif()
endfunction ()
