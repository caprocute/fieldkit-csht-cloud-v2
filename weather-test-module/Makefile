default: build

setup: compile_commands.json src/fk-weather-sidecar-normal.h src/fk-weather-sidecar-jig.h
	
compile_commands.json: platformio.ini
	pio run -t compiledb

build: setup
	pio run

compile:
	pio run

upload: setup
	pio run -t upload

monitor: setup
	pio run -t upload -t monitor

src/fk-weather-sidecar-jig.h: fk-weather-sidecar-jig.bin
	xxd -i $^ > $@
	
src/fk-weather-sidecar-normal.h: fk-weather-sidecar-normal.bin
	xxd -i $^ > $@
	
clean:
	rm -f compile_commands.json
