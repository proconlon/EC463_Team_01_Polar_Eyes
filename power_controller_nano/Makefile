# --- Config ---
BOARD := arduino:avr:nano
PORT  := $(shell ls /dev/tty.usbserial* 2>/dev/null || echo "/dev/ttyUSB0")
SKETCH := ./power_controller_nano.ino

# --- Commands ---
all: compile

install:
	@echo "Installing Arduino CLI..."
	@curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
	@./bin/arduino-cli core update-index
	@./bin/arduino-cli core install arduino:avr

compile:
	@echo "Compiling for $(BOARD)..."
	arduino-cli compile --fqbn $(BOARD) $(SKETCH)

upload: compile
	@echo "Uploading to $(PORT)..."
	arduino-cli upload -p $(PORT) --fqbn $(BOARD) $(SKETCH)

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build