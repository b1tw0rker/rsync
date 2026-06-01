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
exclude_entries=()
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
   local -a source_filter_args=("${@:3}")

   if [ "$output_mode" = "verbose" ]; then
      rsync -avz -e "ssh ${ssh_opts[*]}" "${source_filter_args[@]}" --delete "$sourcepath" "$target:$remotepath" --info=NAME2 2>&1 | tee -a "$log_file"
      return ${PIPESTATUS[0]}
   fi

   rsync -avz -e "ssh ${ssh_opts[*]}" "${source_filter_args[@]}" --delete "$sourcepath" "$target:$remotepath" --info=ALL >> "$log_file" 2>&1
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
   local -a source_filter_args=("${@:3}")
   local cmd=(rsync -avz -e "ssh ${ssh_opts[*]}" "${source_filter_args[@]}" --delete "$sourcepath" "$target:$remotepath" --info=COPY2,DEL2,NAME2,BACKUP2,REMOVE2,SKIP2)

   printf "%q " "${cmd[@]}"
   printf ">> %q\n" "$log_file"
}

normalize_filter_entry() {
   local raw_entry=$1
   local -n mode_ref=$2
   local -n pattern_ref=$3

   if [[ "$raw_entry" == \!* ]]; then
      mode_ref="include"
      pattern_ref=${raw_entry#!}
      return
   fi

   mode_ref="exclude"
   pattern_ref=$raw_entry
}

pattern_has_glob() {
   case "$1" in
      *[\*\?\[]*)
         return 0
         ;;
   esac

   return 1
}

append_filter_rule() {
   local mode=$1
   local rule=$2
   local -n rules_ref=$3
   local prefix="-"

   if [ "$mode" = "include" ]; then
      prefix="+"
   fi

   rules_ref+=(--filter="$prefix $rule")
}

append_include_parent_rules() {
   local relative_entry=$1
   local -n parent_rules_ref=$2
   local parent_path=${relative_entry%/*}
   local segment
   local current_path=""
   local -a segments=()

   if [ "$parent_path" = "$relative_entry" ]; then
      return
   fi

   IFS='/' read -r -a segments <<< "$parent_path"
   for segment in "${segments[@]}"; do
      if [ -z "$segment" ]; then
         continue
      fi

      current_path="$current_path/$segment"
      parent_rules_ref+=(--filter="+ $current_path/")
   done
}

append_relative_filter() {
   local mode=$1
   local entry=$2
   local sourcepath=$3
   local -n relative_rules_ref=$4
   local normalized_entry

   append_filter_rule "$mode" "$entry" relative_rules_ref

   if [ "$mode" != "include" ] || pattern_has_glob "$entry"; then
      return
   fi

   normalized_entry=$(strip_trailing_slashes "$entry")
   if [ -d "$sourcepath/$normalized_entry" ]; then
      append_filter_rule "$mode" "$normalized_entry/***" relative_rules_ref
   fi
}

append_absolute_filter() {
   local mode=$1
   local normalized_source=$2
   local entry=$3
   local -n absolute_rules_ref=$4
   local dir_only=0
   local normalized_entry
   local relative_entry

   if [[ "$entry" == */ ]]; then
      dir_only=1
   fi

   normalized_entry=$(strip_trailing_slashes "$entry")
   if [ "$normalized_entry" = "$normalized_source" ]; then
      return
   fi

   if [ "$normalized_source" = "/" ]; then
      relative_entry=${normalized_entry#/}
   elif [[ "$normalized_entry" == "$normalized_source"/* ]]; then
      relative_entry=${normalized_entry#"$normalized_source"/}
   else
      return
   fi

   if [ -z "$relative_entry" ]; then
      return
   fi

   if [ "$mode" = "include" ] && ! pattern_has_glob "$relative_entry"; then
      append_include_parent_rules "$relative_entry" absolute_rules_ref
   fi

   if [ "$dir_only" -eq 1 ]; then
      append_filter_rule "$mode" "/$relative_entry/" absolute_rules_ref
   else
      append_filter_rule "$mode" "/$relative_entry" absolute_rules_ref
   fi

   if [ "$mode" = "include" ] && ! pattern_has_glob "$relative_entry"; then
      append_filter_rule "$mode" "/$relative_entry/***" absolute_rules_ref
      return
   fi

   if [ "$mode" = "exclude" ] && ! pattern_has_glob "$relative_entry" && [ -d "$normalized_entry" ]; then
      append_filter_rule "$mode" "/$relative_entry/***" absolute_rules_ref
   fi
}

strip_trailing_slashes() {
   local value=$1

   while [ "$value" != "/" ] && [[ "$value" == */ ]]; do
      value="${value%/}"
   done

   printf "%s" "$value"
}

source_is_excluded() {
   local sourcepath=$1
   local normalized_source
   local source_name
   local source_relative
   local raw_entry
   local dir_only
   local mode
   local pattern
   local normalized_pattern
   local match_result=""

   normalized_source=$(strip_trailing_slashes "$sourcepath")
   source_name=${normalized_source##*/}
   source_relative=${normalized_source#/}

   for raw_entry in "${exclude_entries[@]}"; do
      normalize_filter_entry "$raw_entry" mode pattern
      dir_only=0
      if [[ "$pattern" == */ ]]; then
         dir_only=1
      fi
      normalized_pattern=$(strip_trailing_slashes "$pattern")

      if [ "$dir_only" -eq 1 ] && [ ! -d "$sourcepath" ]; then
         continue
      fi

      if [[ "$pattern" == /* ]]; then
         if [[ "$normalized_source" == $normalized_pattern ]]; then
            match_result=$mode
         fi
         continue
      fi

      if [[ "$pattern" == */* ]]; then
         if [[ "$source_relative" == $pattern ]]; then
            match_result=$mode
         fi
         continue
      fi

      if [[ "$source_name" == $pattern ]] || [[ "$source_relative" == $pattern ]]; then
         match_result=$mode
      fi
   done

   if [ "$match_result" = "exclude" ]; then
      return 0
   fi

   return 1
}

build_source_filters() {
   local sourcepath=$1
   local -n source_rules_ref=$2
   local normalized_source
   local raw_entry
   local mode
   local pattern
   local index

   source_rules_ref=()
   normalized_source=$(strip_trailing_slashes "$sourcepath")

   if [ ! -d "$sourcepath" ]; then
      return
   fi

   for ((index=${#exclude_entries[@]} - 1; index>=0; index--)); do
      raw_entry=${exclude_entries[index]}
      normalize_filter_entry "$raw_entry" mode pattern

      if [[ "$pattern" == /* ]]; then
         append_absolute_filter "$mode" "$normalized_source" "$pattern" source_rules_ref
         continue
      fi

      append_relative_filter "$mode" "$pattern" "$normalized_source" source_rules_ref
   done
}

report_excluded_source() {
   local sourcepath=$1
   local message="Skipping excluded source: $sourcepath"

   if [ "$active" = "true" ] && [ "$output_mode" = "verbose" ]; then
      echo "$message"
   fi

   if [ "$active" != "true" ]; then
      echo "$message"
   fi

   if [ -n "${log_file:-}" ]; then
      echo "$message" >> "$log_file"
   fi
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
   local source_filter_args=()

   if source_is_excluded "$sourcepath"; then
      report_excluded_source "$sourcepath"
      return
   fi

   build_source_filters "$sourcepath" source_filter_args

   if [ "$active" = "true" ]; then
      run_rsync "$sourcepath" "$remotepath" "${source_filter_args[@]}"
      rsync_exit=$?
      if [ "$rsync_exit" -ne 0 ]; then
         log_error "ERROR: rsync failed for $sourcepath (exit $rsync_exit)"
      fi
      return
   fi

   print_rsync_command "$sourcepath" "$remotepath" "${source_filter_args[@]}"
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

      exclude_entries+=("$entry")
   done < "$excludefile"

   # Never transfer this job's local configuration, even when /etc/bitworker/ is synced.
   exclude_entries+=("$config_file")
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
   if [ "$active" = "true" ]; then
      check_ssh_connectivity
   fi
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

if [ ! -f "$copyfolder" ]; then
   exit 0
fi

main
exit $?
