#!/bin/bash

SCAN_DIR=/mnt/c/Users/tomco/OneDrive/Documents/Scans
DEST_TREE=/mnt/c/Users/tomco/OneDrive
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
# dirs under directory `d` which can include symlinks,
# which will be followed
print_directories() {
  find "/mnt/c/Users/tomco/OneDrive/$1" -type d -not -path "*/\.*"
}
destination_dir_ideas() {
  print_directories 0-Scan
  print_directories ABC
  print_directories Documents/Scans
  print_directories IncomeTax
  print_directories James
  print_directories Money
  print_directories "Practice Papers"
  print_directories Songs
  print_directories Documents
}

# fzf UI to select destination directory
select_destination_dir() {
  fzf -i --height ~40% <"$dirlist"
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
  dirlist=~/.local/state/scorg-directories.txt
  format_sf="Source File:           %s\n"
  format_dd="Destination Directory: %s\n"
  format_df="Destination Filename:  %s\n"

  while true; do

    # What is the source file?
    if [ -z "$SRC_FILE" ]; then
      SRC_FILE="$SCAN_DIR/$(
        cd $SCAN_DIR
        select_source_file
      )"
    fi
    if [ -n "$SRC_FILE" ]; then
      printf "$format_sf" "$(basename "$SRC_FILE")"
    else
      printf "$format_sf" "[None]"
    fi

    # Act on source file.
    prompt_action 'Acquire scan / File / View / Delete / Mkdir / Cache dirlist / Skip / Quit? [Fvdmcsq] '
    if [ "$action" = "d" ]; then
      action=s
      rm -v "$SRC_FILE"
    elif [ "$action" = "v" ]; then
      action=s
      wslview "$SRC_FILE"
    elif [ "$action" = "m" ]; then
      action=s
      parent_dir=$(select_destination_dir)
      prompt_newdir "$parent_dir"
      if [ -n "$newdir" ]; then
        mkdir -pv "$newdir"
        echo "$newdir" >>"$dirlist"
      fi
    elif [[ "$action" == "c" || ! -e "$dirlist" ]]; then
      action=s
      printf "Listing directories..."
      destination_dir_ideas | sort | uniq >"$dirlist"
      printf "done\n"
    elif [ "$action" = "a" ]; then
      action=s
      printf "Acquiring scan..."
      naps2.console -p C300DpxAuto -a
      printf "done\n"
    fi
    [ "$action" = "q" ] && break
    [ "$action" = "s" ] && continue

    # What is the destination directory?
    printf "Select destination directory\n"
    DEST_DIR=$(select_destination_dir)
    if [ -z "$DEST_DIR" ]; then
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
    DEST_FILENAME=$(select_filename "$suffix")
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
