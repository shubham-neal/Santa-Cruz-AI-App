# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

if(DEFINED OPENCV_INITIAL_PASS)
  return()
endif()

cmake_minimum_required(VERSION 3.1)
project(gapi_azure_samples)
set(CMAKE_CXX_STANDARD 11)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DUSE_EDGE_MODULES")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DUSE_EDGE_MODULES")

find_package(OpenCV REQUIRED gapi_azure highgui)
find_package(mxIf REQUIRED)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTREAMER gstreamer-1.0>=1.14 REQUIRED)
pkg_check_modules(RTSP gstreamer-rtsp-server-1.0 REQUIRED)

set(AZUREIOT_INCLUDE_DIRS "/usr/local/include/azureiot")

set(APP_NAME inference)

file (GLOB MAIN_SRC ${CMAKE_CURRENT_SOURCE_DIR}/*.c*)
file (GLOB MAIN_HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/*.h*)

add_executable(${APP_NAME} ${MAIN_SRC} ${MAIN_HEADERS})

target_include_directories(${APP_NAME}
  PRIVATE
    ${GSTREAMER_INCLUDE_DIRS}
    ${RTSP_INCLUDE_DIRS}
    ${AZUREIOT_INCLUDE_DIRS}
  )

target_link_libraries(${APP_NAME}
  PRIVATE
    ${OpenCV_LIBS}
    mxIf
    ${GSTREAMER_LIBRARIES}
    ${RTSP_LIBRARIES}
    iothub_client_mqtt_transport
    iothub_client
    parson
    umqtt
    prov_auth_client
    hsm_security_client
    uhttp
    aziotsharedutil
    pthread
    curl
    ssl
    crypto
    m
    uuid
    usb-1.0
    udev
)
