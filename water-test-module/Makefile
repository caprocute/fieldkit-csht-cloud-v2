export MODALITY ?= "MODALITY_TEMPERATURE"

default: build

setup: compile_commands.json
	
compile_commands.json: platformio.ini
	pio run -t compiledb

build: setup
	pio run

compile:
	pio run

temp:
	rm -f compile_commands.json
	MODALITY="MODALITY_TEMPERATURE" $(MAKE) setup
	MODALITY="MODALITY_TEMPERATURE" $(MAKE) build
	mkdir -p build/temp
	cp .pio/build/featheresp32/firmware.* build/temp

ec: 
	rm -f compile_commands.json
	MODALITY="MODALITY_EC" $(MAKE) setup
	MODALITY="MODALITY_EC" $(MAKE) build
	mkdir -p build/ec
	cp .pio/build/featheresp32/firmware.* build/ec

do:
	rm -f compile_commands.json
	MODALITY="MODALITY_DO" $(MAKE) setup
	MODALITY="MODALITY_DO" $(MAKE) build
	mkdir -p build/do
	cp .pio/build/featheresp32/firmware.* build/do

ph:
	rm -f compile_commands.json
	MODALITY="MODALITY_PH" $(MAKE) setup
	MODALITY="MODALITY_PH" $(MAKE) build
	mkdir -p build/ph
	cp .pio/build/featheresp32/firmware.* build/ph

all: temp ec do ph

upload: setup
	pio run -t upload

clean:
	rm -rf compile_commands.json build
