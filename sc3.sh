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

# list of source files, just files in SCAN_DIR
# without a recursive search
xsource_file_ideas() {
  find "$SCAN_DIR" -maxdepth 1 -type f -not -path "*/\.*" | head -10
}

# path of one source file
xone_source_file() {
  source_file_ideas | head -1
}

# list of destination directories - recursive list of
# dirs under specified directory
xprint_directories() {
  find "$ONEDRIVE_DIR/$1" -type d -not -path "*/\.*"
}

# fzf UI to select directory
select_dir() {
  (
    cd "$ONEDRIVE_DIR"
    fzf
  )
}
xselect_destination_dir() {
  #fzf -i --height ~40% <"$dirlist"
  DEST_DIR="$(select_dir)"
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
clear_back_line() {
  # clear to beginning of line
  echo -e "\033[2K\r"

}
read_1() {
  local foo
  read -n 1 -p "$1" one_char
  printf "%s" "$one_char"
}

action=$(prompt_one)
printf "\n-->%s<--" $action
exit 0
prompt_newdir() {
  read -e -i "$1" -p "Mkdir: " newdir
}

prompt_date() {
  read -e -i "$1" -p "Date string: " date
  # TODO fzf it
}

HELP_TEXT="$cat <<END_HELP_TEXT"
i select incoming file
I acquire incoming file from scanner
v view incoming file
f move incoming file to destination path
x delete incoming file
n select names
N create names
y format date as year
m format date as year and month
d format date as year, month, and day
D set date
p select destination
P create subdirectory of destination
? show help
q quit
END_HELP_TEXT

# Announce
printf "OneDrive location: %s\n" "$ONEDRIVE_DIR"
printf "Inbox location: %s\n" "$SCAN_DIR"

DEST_TREE="$ONEDRIVE_DIR"
SRC_FILE=
DEST_DIR="$(select_dir)"
DEST_FILENAME=

destination_path() {
  printf "%s/%s-%s" "$DEST_DIR" "$FILE_DATE" "$NAMES"
}

main() {
  while true; do

    printf "Incoming: %s\nNames: %s\nFile Date: %s\nDestination: %s\nFull destination: %s\n" \
      "$(basename "$SRC_FILE")" "$NAMES" "$FILE_DATE" "$DEST_DIR" "$(destination_path)"

    prompt_action '\n[iIvfx]Incoming [nN]Names [ymdD]Date [pP]Path [?]Help [q]Quit  |>'
    #prompt_action 'Acquire / File / View / Delete / Mkdir / show dirList / Cache dirlist / Skip / Quit :'
    if [[ "$action" == "?" ]]; then
      printf "%s" "$HELP_TEXT"
    elif [[ "$action" == "i" ]]; then
      # select incoming file
      SRC_FILE="$SCAN_DIR/$(
        cd $SCAN_DIR
        fzf
      )"
      if [[ ! -n "$SRC_FILE" ]]; then
        SRC_FILE="[None]"
      fi
    elif [ "$action" = "a" ]; then
      prompt_action 'Glass / Feeder / Duplex? [gfd]'
      unset scanprofile
      if [[ "$action" == "g" ]]; then
        scanprofile=C300GlsAuto
      elif [[ "$action" == "f" ]]; then
        scanprofile=C300FdrAuto
      elif [[ "$action" == "d" ]]; then
        scanprofile=C300DpxAuto
      fi
      [[ -v scanprofile ]] && naps2.console -p "$scanprofile" -a
    elif [ "$action" = "v" ]; then
      wslview "$SRC_FILE"
    elif [ "$action" = "x" ]; then
      action=s
      rm -v "$SRC_FILE"
    elif [ "$action" = "y" ]; then
    elif [ "$action" = "m" ]; then
    elif [ "$action" = "d" ]; then
    elif [ "$action" = "D" ]; then
      FILE_DATE="$(prompt_date)"
    elif [ "$action" = "P" ]; then
      action=s
      if [[ ! -d "$DEST_DIR" ]]; then
        echo "Select parent directory"
        parent_dir=$(select_dir)
      fi
      prompt_newdir "$DEST_DIR"
      if [[ -n "$newdir" ]]; then
        mkdir -pv "$newdir"
      fi
    elif [ "$action" = "q" ]; then
      break
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
