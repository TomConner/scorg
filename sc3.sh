#!/bin/bash

SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
SCORG_VERSION=0.3
printf "Scorg %s from %s\n" "$SCORG_VERSION" "$SCRIPT_DIR"

# Find OneDrive directory via Windows environment variable
ONEDRIVE_WIN="$(cmd.exe /c "echo %OneDrive%" 2>/dev/null | tr -d '\r')"
if [[ "$ONEDRIVE_WIN" != "%OneDrive%" ]] && [[ -n "$ONEDRIVE_WIN" ]]; then
  ONEDRIVE_DIR="$(wslpath "$ONEDRIVE_WIN")"
fi

# Error if OneDrive is not found
if [[ ! -d "$ONEDRIVE_DIR" ]]; then
  echo "OneDrive location not found; ensure OneDrive is installed and running"
  exit 1
fi

# Error if SCAN_DIR is not found
SCAN_DIR="$ONEDRIVE_DIR/Documents/Scans"
if [[ ! -d "$SCAN_DIR" ]]; then
  echo "$SCAN_DIR not found; ensure this exists and is syncing to this machine"
  exit 1
fi

# Check if fzf is installed
if ! command -v fzf &>/dev/null; then
  echo "Error: fzf is required but not installed."
  echo "Install it with your package manager:"
  echo "  - Debian/Ubuntu: sudo apt install fzf"
  echo "  - macOS: brew install fzf"
  echo "  - Arch Linux: sudo pacman -S fzf"
  exit 1
fi

# Announce
printf "OneDrive location: %s\n" "$ONEDRIVE_DIR"
printf "Inbox location: %s\n" "$SCAN_DIR"

DEST_TREE="$ONEDRIVE_DIR"
SRC_FILE=
DEST_DIR=
DEST_FILENAME=

# list of source files, just files in SCAN_DIR
# without a recursive search
xsource_file_ideas() {
  find "$SCAN_DIR" -maxdepth 1 -type f -not -path "*/\.*" | head -10
}

# path of one source file
xone_source_file() {
  source_file_ideas | head -1
}

# fzf UI to select source file
select_source_file() {
  fzf -i --height ~40% -q pdf
}

# list of destination directories - recursive list of
# dirs under specified directory
print_directories() {
  find "$ONEDRIVE_DIR/$1" -type d -not -path "*/\.*"
}

# fzf UI to select destination directory
select_destination_dir() {
  #fzf -i --height ~40% <"$dirlist"
  (
    cd "$ONEDRIVE_DIR"
    fzf -i
  )
}

print_days() {
  # Calculate total months to display (4 years = 48 months)
  local total_days=$1

  for ((d = 0; d < total_days; d++)); do
    ymd=$(date --date="$d days ago" +"%Y-%m-%d")
    printf "%s-%s\n" "$ymd" "$suffix"
  done
}

print_months() {
  # Calculate total months to display (4 years = 48 months)
  local total_months=$1

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
}

# list of timestamped filenames
filename_ideas() {
  local suffix="$1"
  printf "%s\n" "$(basename "$SRC_FILE")"

  # Get current year and month
  current_year=$(date +%Y)
  current_month=$(date +%m)
  current_day=$(date +%d)

  print_days 60
  print_months 18
}

select_filename() {
  filename_ideas "$1" | fzf -i --height ~40%
}

suffix_ideas() {
  ./suffixes \
    --source-file "$SRC_FILE" \
    --destination-directory "$DEST_DIR"
}

select_suffix() {
  suffix_ideas | fzf -i --height ~40%
}

prompt_action() {
  read -n 1 -p "$1" action
  printf "\n"
}

prompt_newdir() {
  read -e -i "$1" -p "Mkdir: " newdir
}

main() {
  format_sf="Source File:           %s\n"
  format_dd="Destination Directory: %s\n"
  format_df="Destination Filename:  %s\n"

  while true; do

    printf "Incoming: %s  Names: %s  Date: %s  Path: %s\n" \
      "$(basename "$SRC_FILE")" "$NAMES" "$FILE_DATE" "$DEST_DIR"

    # What is the source file?
    if [[ -z "$SRC_FILE" || ! -e "$SRC_FILE" ]]; then
      echo "Select incoming file..."
      SRC_FILE="$SCAN_DIR/$(
        cd $SCAN_DIR
        select_source_file
      )"
    fi
    if [[ ! -n "$SRC_FILE" ]]; then
      SRC_FILE="[None]"
    fi

    # Act on source file.
    prompt_action '[iI]Incoming [nN]Names [ymdD]Date [p]Path [m]Mkdir [v]View [q]Quit  |>'
    #prompt_action 'Acquire / File / View / Delete / Mkdir / show dirList / Cache dirlist / Skip / Quit :'
    if [ "$action" = "d" ]; then
      action=s
      rm -v "$SRC_FILE"
    elif [ "$action" = "v" ]; then
      action=s
      wslview "$SRC_FILE"
    elif [ "$action" = "m" ]; then
      action=s
      echo "Select parent directory"
      parent_dir=$(select_destination_dir)
      prompt_newdir "$parent_dir"
      if [ -n "$newdir" ]; then
        mkdir -pv "$newdir"
      fi
    elif [ "$action" = "a" ]; then
      action=s
      prompt_action 'Glass / Feeder / Duplex? [gfd]'
      if [[ "$action" == "g" ]]; then
        scanprofile=C300DpxAuto
      fi
      printf "Acquiring scan..."
      naps2.console -p "$scanprofile" -a
      printf "done\n"
    fi
    [ "$action" = "q" ] && break

    # What is the destination directory?
    printf "Select destination directory\n"
    DEST_DIR=$(select_destination_dir)
    if [[ -z "$DEST_DIR" ]]; then
      prompt_action 'Delete / Skip / Quit? [dsq] '
      if [ "$action" = "d" ]; then
        rm -v $SRC_FILE
        continue
      fi
      [ "$action" = "q" ] && break
      [ "$action" = "s" ] && continue
    fi
    printf "$format_dd" "$DEST_DIR"

    # What is the suffix for the destination filename?
    prompt_action 'select suFfix / Delete / Skip / Quit? [fdsq] '
    if [ "$action" = "f" ]; then
      suffix=$(select_suffix)
      [ -n "$suffix" ] || read -e -p 'Suffix: ' suffix
      [ -n "$suffix" ] || break
    elif [ "$action" = "d" ]; then
      rm -v $SRC_FILE
      continue
    elif [ "$action" = "q" ]; then
      break
    elif [ "$action" = "s" ]; then
      continue
    fi

    # What is the destination filename?
    echo "Select destination filename... (ESC to type instead of select)"
    DEST_FILENAME=$(select_filename "$suffix")
    [ -n "$DEST_FILENAME" ] || read -e -p 'Destination filename: ' DEST_FILENAME
    [ -n "$DEST_FILENAME" ] || break
    DEST_FILENAME="$(basename "$DEST_FILENAME")".pdf
    printf "$format_df" "$DEST_FILENAME"

    # Move the file.
    mv -iv "$SRC_FILE" "$DEST_DIR"/"$DEST_FILENAME"
    printf "\n"
  done

}

# Run the main function
main
