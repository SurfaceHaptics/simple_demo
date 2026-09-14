cmake_minimum_required(VERSION 3.13.0)
project(PhotoFeel)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/tools/cmake-common" ${CMAKE_MODULE_PATH})
set(CMAKE_PREFIX_PATH "${CMAKE_CURRENT_BINARY_DIR}" ${CMAKE_PREFIX_PATH})
include(init-cpp)

find_package(Qt5 CONFIG)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

add_subdirectory(src)

# qt.conf for self-contained run
configure_file(qt.conf.in ${CMAKE_CURRENT_BINARY_DIR}/qt.conf COPYONLY)
file(COPY "${CMAKE_CURRENT_BINARY_DIR}/qt.conf" DESTINATION ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
