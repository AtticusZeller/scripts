#!/bin/bash




# Configuration
SCREENSHOT_FILE="/tmp/ocr_screenshot.png"
OCR_OUTPUT="/tmp/ocr_output.txt"
LANG="eng" # OCR language
# Function to show notifications
notify() {
notify-send "OCR Screenshot" "$1"
}

# Error handling function
error_exit() {
notify "Error: $1"
exit 1
}

gnome-screenshot -a -f "$SCREENSHOT_FILE" || error_exit "Failed to take screenshot"

# Run OCR
tesseract "$SCREENSHOT_FILE" stdout -l "$LANG" | tee "$OCR_OUTPUT" | xclip -selection clipboard

# Check if OCR output is empty
if [ ! -s "$OCR_OUTPUT" ]; then
error_exit "OCR produced no output"
fi
# Notify success
notify "Text extracted and copied to clipboard"
# Clean up
rm -f "$SCREENSHOT_FILE" "$OCR_OUTPUT"