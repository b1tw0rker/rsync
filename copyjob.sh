#!/bin/bash

### Version: 1.0.3
### Build date: 08.05.2026
### (C) 2021-2026 by Dipl. Wirt.-Ing. Nick Herrmann
### This program is WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
###
###

set -u
set -o pipefail

script=$(readlink -f "$0")
path=$(dirname "$script")
config_file="$path/config.cf"
source "$config_file"

start_ts=$(date +%s)
ssh_opts=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5)
output_mode="${output_mode:-silent}"
exclude_args=()
had_errors=0

log_error() {
   local message=$1

   echo "$message" >&2
   if [ -n "${log_file:-}" ]; then
      echo "$message" >> "$log_file"
   fi
   had_errors=1
}

trim_line() {
   local line=$1

   line="${line%$'\r'}"
   line="${line#"${line%%[![:space:]]*}"}"
   line="${line%"${line##*[![:space:]]}"}"
   printf "%s" "$line"
}

validate_required_file() {
   local file_path=$1
   local label=$2

   if [ ! -f "$file_path" ]; then
      echo "ERROR: Missing $label file: $file_path" >&2
      exit 1
   fi
}

ensure_log_directory() {
   if [ -e "$logpath" ] && [ ! -d "$logpath" ]; then
      echo "ERROR: logpath exists but is not a directory: $logpath" >&2
      exit 1
   fi

   if ! mkdir -p "$logpath"; then
      echo "ERROR: Cannot create log directory: $logpath" >&2
      exit 1
   fi
}

validate_settings() {
   case "$output_mode" in
      silent|verbose)
         ;;
      *)
         echo "ERROR: output_mode must be silent or verbose in $config_file" >&2
         exit 1
         ;;
   esac

   case "$active" in
      true|false)
         ;;
      *)
         echo "ERROR: active must be true or false in $config_file" >&2
         exit 1
         ;;
   esac
}

configure_target() {
   local user_target

   if [ "$target" != "XXX" ]; then
      return
   fi

   printf "\n\n***********************************************\n\nAdd Your BackupServer (FQDN) to config.cf: "
   read -r user_target

   if [ -z "$user_target" ]; then
      echo "ERROR: target must not be empty" >&2
      exit 1
   fi

   sed -i 's/^target="XXX"/target="'"$user_target"'"/' "$config_file"
   source "$config_file"
}

run_rsync() {
   local sourcepath=$1
   local remotepath=$2

   if [ "$output_mode" = "verbose" ]; then
      rsync -avz -e "ssh ${ssh_opts[*]}" "${exclude_args[@]}" --delete "$sourcepath" "$target:$remotepath" --info=NAME2 2>&1 | tee -a "$log_file"
      return ${PIPESTATUS[0]}
   fi

   rsync -avz -e "ssh ${ssh_opts[*]}" "${exclude_args[@]}" --delete "$sourcepath" "$target:$remotepath" --info=ALL >> "$log_file" 2>&1
}

format_duration() {
   local total_seconds=$1
   local hours=$((total_seconds / 3600))
   local minutes=$(((total_seconds % 3600) / 60))
   local seconds=$((total_seconds % 60))

   printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
}





### check
###
print_rsync_command() {
   local sourcepath=$1
   local remotepath=$2
   local cmd=(rsync -avz -e "ssh ${ssh_opts[*]}" "${exclude_args[@]}" --delete "$sourcepath" "$target:$remotepath" --info=COPY2,DEL2,NAME2,BACKUP2,REMOVE2,SKIP2)

   printf "%q " "${cmd[@]}"
   printf ">> %q\n" "$log_file"
}

resolve_sources() {
   local pattern=$1
   local -n resolved_ref=$2
   local match

   resolved_ref=()

   if [[ "$pattern" == *[*?[]* ]]; then
      while IFS= read -r match; do
         resolved_ref+=("$match")
      done < <(compgen -G "$pattern")
      return
   fi

   if [ -e "$pattern" ]; then
      resolved_ref+=("$pattern")
   fi
}

process_sync() {
   local sourcepath=$1
   local remotepath=$2
   local rsync_exit=0

   if [ "$active" = "true" ]; then
      run_rsync "$sourcepath" "$remotepath"
      rsync_exit=$?
      if [ "$rsync_exit" -ne 0 ]; then
         log_error "ERROR: rsync failed for $sourcepath (exit $rsync_exit)"
      fi
      return
   fi

   print_rsync_command "$sourcepath" "$remotepath"
}

process_folder_entry() {
   local entry=$1
   local sourcepath
   local remotepath

   if [[ "$entry" != /* ]]; then
      log_error "ERROR: Folder entry must be absolute: $entry"
      return
   fi

   if [[ "$entry" != */ ]]; then
      log_error "ERROR: Folder entry must end with /: $entry"
      return
   fi

   sourcepath="$entry"
   remotepath="${entry%/}"

   if [ ! -e "$sourcepath" ]; then
      log_error "ERROR: Folder source does not exist: $sourcepath"
      return
   fi

   process_sync "$sourcepath" "$remotepath"
}

process_file_entry() {
   local entry=$1
   local sourcepath
   local remotepath
   local matches=()

   if [[ "$entry" != /* ]]; then
      log_error "ERROR: File entry must be absolute: $entry"
      return
   fi

   if [[ "$entry" == */ ]]; then
      log_error "ERROR: File entry must not end with /: $entry"
      return
   fi

   resolve_sources "$entry" matches
   if [ "${#matches[@]}" -eq 0 ]; then
      log_error "ERROR: File source does not exist or pattern matched nothing: $entry"
      return
   fi

   for sourcepath in "${matches[@]}"; do
      remotepath="$sourcepath"
      process_sync "$sourcepath" "$remotepath"
   done
}

process_entries() {
   local list_file=$1
   local entry_type=$2
   local raw_line
   local entry

   while IFS= read -r raw_line || [ -n "$raw_line" ]; do
      entry=$(trim_line "$raw_line")

      if [ -z "$entry" ] || [[ "$entry" == \#* ]]; then
         continue
      fi

      case "$entry_type" in
         folder)
            process_folder_entry "$entry"
            ;;
         file)
            process_file_entry "$entry"
            ;;
      esac
   done < "$list_file"
}

build_excludes() {
   local raw_line
   local entry

   while IFS= read -r raw_line || [ -n "$raw_line" ]; do
      entry=$(trim_line "$raw_line")

      if [ -z "$entry" ] || [[ "$entry" == \#* ]]; then
         continue
      fi

      exclude_args+=(--exclude="$entry")
   done < "$excludefile"
}

check_ssh_connectivity() {
   if ssh -q -o BatchMode=yes "${ssh_opts[@]}" "$target" exit 2>/dev/null; then
      return
   fi

   echo "ERROR: Cannot connect to $target - aborting" >&2
   exit 1
}

main() {
   validate_required_file "$copyfolder" "folder list"
   validate_required_file "$copyfiles" "file list"
   validate_required_file "$excludefile" "exclude list"
   ensure_log_directory

   log_file="$logpath/rsync-$date.log"

   validate_settings
   configure_target

   if [ "$active" != "true" ]; then
      echo "DRY RUN: active=$active in $config_file - commands are only printed, nothing is copied."
   fi

   find "$logpath" -name "rsync-*.log" -mtime +30 -delete 2>/dev/null
   check_ssh_connectivity
   build_excludes
   process_entries "$copyfolder" folder
   process_entries "$copyfiles" file

   end_ts=$(date +%s)
   duration=$((end_ts - start_ts))
   if [ "$output_mode" = "verbose" ]; then
      echo "Runtime: $(format_duration "$duration")"
   fi
   echo "Runtime: $(format_duration "$duration")" >> "$log_file"

   if [ "$had_errors" -ne 0 ]; then
      exit 1
   fi
}
###
if [ ! -f "$copyfolder" ]; then
   exit 0
fi
main
exit $?