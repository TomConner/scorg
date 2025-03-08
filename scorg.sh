#!/bin/bash

SCAN_DIR=/mnt/c/Users/tomco/OneDrive/Documents/Scans
SRC_FILE=
DEST_DIR=
DEST_FILENAME=

# Check if fzf is installed
if ! command -v fzf &>/dev/null; then
  echo "Error: fzf is required but not installed."
  echo "Install it with your package manager:"
  echo "  - Debian/Ubuntu: sudo apt install fzf"
  echo "  - macOS: brew install fzf"
  echo "  - Arch Linux: sudo pacman -S fzf"
  exit 1
fi

# list of source files, just files in SCAN_DIR
# without a recursive search
source_file_ideas() {
  find "$SCAN_DIR" -maxdepth 1 -type f -not -path "*/\.*" | head -10
}

# path of one source file
one_source_file() {
  source_file_ideas | head -1
}

# fzf UI to select source file
select_source_file() {
  source_file_ideas | fzf -i --height ~75%
}

# list of destination directories - recursive list of
# dirs under `destinations` which can include symlinks,
# which will be followed
destination_dir_ideas() {
  find -L destinations -type d -not -path "*/\.*" | sort
}

# fzf UI to select destination directory
select_destination_dir() {
  destination_dir_ideas | fzf -i --height ~75%
}

# list of timestamped filenames
filename_ideas() {
  local suffix="$1"

  # Get current year and month
  current_year=$(date +%Y)
  current_month=$(date +%m)

  # Calculate total months to display (4 years = 48 months)
  total_months=18

  for ((i = 0; i < total_months; i++)); do
    # Calculate the year and month
    month=$((current_month - (i % 12)))
    year_offset=$((i / 12))

    if [ $month -le 0 ]; then
      month=$((month + 12))
      year_offset=$((year_offset + 1))
    fi

    year=$((current_year - year_offset))

    printf "%04d-%02d-%s\n" $year $month "$suffix"
  done
  printf "%s\n" "$(basename "$SRC_FILE")"
}

select_filename() {
  filename_ideas "$1" | fzf -i
}

suffix_ideas() {
  ./suffixes \
    --source-file "$SRC_FILE" \
    --destination-directory "$DEST_DIR"
}

select_suffix() {
  suffix_ideas | fzf -i
}

main() {
  format1="Source File:           %s\n"
  format2="Destination Directory: %s\n"
  format3="Destination Filename:  %s\n"

  while
    #
    # Select source file, quit if no selection
    #
    SRC_FILE=$(one_source_file)
    [ -n "$SRC_FILE" ]
  do
    #
    # Open source file in browser, print filename in console
    printf "$format1" "$(basename "$SRC_FILE")"
    wslview "$SRC_FILE"

    #
    # Select destination directory, quit if no selection else
    # print selection in console
    #
    DEST_DIR=$(select_destination_dir)
    [ -z "$DEST_DIR" ] && break
    printf "$format2" "$DEST_DIR"
    ls "$DEST_DIR"

    #
    # Select suffix, prompt for suffix if no selection
    #
    suffix=$(select_suffix)
    [ -n "$suffix" ] || read -e -p 'Suffix: ' suffix
    #[ -n "$suffix" ] || read -e -i "$(basename "$SRC_FILE")" -p 'Suffix: ' suffix

    #
    # Select filename, quit if no selection else print selection
    # in console
    #
    DEST_FILENAME=$(select_filename "$suffix")
    [ -n "$DEST_FILENAME" ] || break
    DEST_FILENAME="$(basename "$DEST_FILENAME")".pdf
    printf "$format3" "$DEST_FILENAME"

    #
    # Move file
    #
    mv -v "$SRC_FILE" "$DEST_DIR"/"$DEST_FILENAME"
    printf "\n"
  done
}

# Run the main function
main
