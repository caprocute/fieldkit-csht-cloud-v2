if (TARGET WiFi101)
  return()
endif()

if ("${WiFi101_PATH}" STREQUAL "")
  include(${CMAKE_CURRENT_SOURCE_DIR}/dependencies.cmake)
endif()

set(WiFi101_RECURSE True)

add_external_arduino_library(WiFi101)

find_package(SPI)
target_link_libraries(WiFi101 SPI)

find_package(SeggerRTT)
target_link_libraries(WiFi101 SeggerRTT)

target_compile_definitions(WiFi101  PUBLIC -DM2M_LOG_LEVEL=${M2M_LOG_LEVEL})

target_include_directories(WiFi101
    PUBLIC ${WiFi101_PATH}/src/utility ${WiFi101_PATH}/src/host_drv
    PRIVATE ${WiFi101_PATH}/src/utility ${WiFi101_PATH}/src/host_drv
)
