#!/bin/bash

set -xe

BUILD=$1
FK_VERSION=$2
FK_VERSION_PATH=${FK_VERSION//\//_}
PACKAGE=fk-samd09-firmware-${FK_VERSION_PATH}
PROJECT=${BUILD}/../..

mkdir -p ${BUILD}/${PACKAGE}
cp ${PROJECT}/tools/flash-weather ${BUILD}/${PACKAGE}
cp ${PROJECT}/tools/jlink-weather ${BUILD}/${PACKAGE}
cp ${BUILD}/../samd09/modules/weather/sidecar/fk-weather-sidecar*.elf ${BUILD}/${PACKAGE}
cp ${BUILD}/../samd09/modules/weather/sidecar/fk-weather-sidecar*.bin ${BUILD}/${PACKAGE}
chmod 755 ${BUILD}/${PACKAGE}/flash-*
chmod 755 ${BUILD}/${PACKAGE}/jlink-*
cd ${BUILD} && zip -r ${PACKAGE}.zip ${PACKAGE}
cp ${BUILD}/${PACKAGE}.zip ${BUILD}/fk-samd09-firmware.zip
