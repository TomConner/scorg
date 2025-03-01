#!/bin/bash

SCAN_DIR=/mnt/c/Users/tomco/OneDrive/Documents/Scans

# Check if fzf is installed
if ! command -v fzf &>/dev/null; then
  echo "Error: fzf is required but not installed."
  echo "Install it with your package manager:"
  echo "  - Debian/Ubuntu: sudo apt install fzf"
  echo "  - macOS: brew install fzf"
  echo "  - Arch Linux: sudo pacman -S fzf"
  exit 1
fi

# Function to select source file
select_source_file() {
  find "$SCAN_DIR" -maxdepth 1 -type f | head -1
}

# Function to select destination directory
select_destination_dir() {
  echo "Select a destination directory:"
  find -L destinations -type d -not -path "*/\.*" | sort | fzf
}

# Main process
main() {
  # Select source file
  SRC_FILE=$(select_source_file)
  if [ -z "$SRC_FILE" ]; then
    echo "No source file selected. Exiting."
    exit 0
  fi
  wslview "$SRC_FILE"

  #echo "Selected source: $SRC_FILE"

  # Select destination directory
  DEST_DIR=$(select_destination_dir)
  if [ -z "$DEST_DIR" ]; then
    echo "No destination directory selected. Exiting."
    exit 0
  fi

  echo "Selected destination: $DEST_DIR"

  # Extract filename from source path
  FILENAME=$(basename "$SRC_FILE")
  DEST_PATH="$DEST_DIR/$FILENAME"

  # Confirm operation
  echo -e "\nReady to copy:"
  echo "  Source: $SRC_FILE"
  echo "  Destination: $DEST_PATH"
  echo
  read -p "Proceed with copy? (y/n): " CONFIRM

  if [[ $CONFIRM == "y" || $CONFIRM == "Y" ]]; then
    # Perform the copy
    cp -v "$SRC_FILE" "$DEST_DIR"
    echo "Copy completed."
  else
    echo "Operation cancelled."
  fi
}

# Run the main function
main
