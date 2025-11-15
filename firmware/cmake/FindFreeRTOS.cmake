if (TARGET FreeRTOS)
  return()
endif()

set(FreeRTOS_PATH ${CMAKE_SOURCE_DIR}/third-party/Arduino-FreeRTOS-SAMD51)

if(${TARGET_ARCH} MATCHES "amd64")
  file(GLOB sources ${FreeRTOS_PATH}/src/list.c)
  add_library(FreeRTOS STATIC "${sources}")
else()
  file(GLOB sources ${FreeRTOS_PATH}/src/*.c ${FreeRTOS_PATH}/src/*.cpp)
  add_arduino_library(FreeRTOS "${sources}")
endif()

find_package(arduino-logging)
target_link_libraries(FreeRTOS arduino-logging)

find_package(SeggerRTT)
target_link_libraries(FreeRTOS SeggerRTT)

target_include_directories(FreeRTOS
    PUBLIC ${FreeRTOS_PATH}/src
    PRIVATE ${FreeRTOS_PATH}/src
)


