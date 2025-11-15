default: build

setup: compile_commands.json
	
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
	
clean:
	rm -f compile_commands.json
