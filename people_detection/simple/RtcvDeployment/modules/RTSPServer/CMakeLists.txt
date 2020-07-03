cmake_minimum_required(VERSION 3.14)

project(rtspserver)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTLIBS REQUIRED
        gstreamer-1.0
        gstreamer-rtsp-server-1.0
        )

set(CMAKE_CXX_STANDARD 11)
#set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Werror")

set(THESE_SOURCES "src/main.cpp")
include_directories (${GSTLIBS_INCLUDE_DIRS})
link_directories (${GSTLIBS_LIBRARY_DIRS})

message(STATUS ${GSTLIBS_INCLUDE_DIRS})
message(STATUS ${GSTLIBS_CFLAGS})

add_executable (rtspserver ${THESE_SOURCES})

add_definitions (${GSTLIBS_CFLAGS_OTHER})
target_link_libraries (rtspserver ${GSTLIBS_LIBRARIES})
