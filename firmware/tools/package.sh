#!/bin/bash

set -xe

BUILD=$1
FK_VERSION=$2
FK_VERSION_PATH=${FK_VERSION//\//_}
PACKAGE=fk-firmware-${FK_VERSION_PATH}
PROJECT=${BUILD}/../..

mkdir -p ${PROJECT}/${PACKAGE}
cp ${PROJECT}/tools/flash-* ${PROJECT}/${PACKAGE}
cp ${PROJECT}/tools/jlink-* ${PROJECT}/${PACKAGE}
cp ${BUILD}/version.txt ${PROJECT}/${PACKAGE}
cp ${BUILD}/bootloader/fkbl.elf ${PROJECT}/${PACKAGE}
cp ${BUILD}/bootloader/fkbl-fkb.bin ${PROJECT}/${PACKAGE}
cp ${BUILD}/fk/fk-bundled-fkb.elf ${PROJECT}/${PACKAGE}
cp ${BUILD}/fk/fk-bundled-fkb.bin ${PROJECT}/${PACKAGE}
cp ${PROJECT}/third-party/wifi_driver/ssl*.bin ${PROJECT}/${PACKAGE}
cp ${PROJECT}/third-party/wifi_driver/m2m_aio_3a0.bin ${PROJECT}/${PACKAGE}/winc1500.bin
chmod 755 ${PROJECT}/${PACKAGE}/flash-*
chmod 755 ${PROJECT}/${PACKAGE}/jlink-*
touch ${PROJECT}/${PACKAGE}/fk.cfg-disabled
cd ${PROJECT} && zip -r ${PACKAGE}.zip ${PACKAGE}
cp ${PROJECT}/${PACKAGE}.zip ${BUILD}/fk-firmware.zip
