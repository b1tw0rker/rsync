#!/bin/bash

### Version: 1.0.3
### Build date: 08.05.2026
### (C) 2021-2026 by Dipl. Wirt.-Ing. Nick Herrmann
### This program is WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
###
###

set -u

script=$(readlink -f "$0")
path=`dirname "$script"`
config_file="$path/config.cf"
source "$config_file"

start_ts=$(date +%s)
ssh_opts=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5)
output_mode="${output_mode:-silent}"

run_rsync() {
   local sourcepath=$1
   local remotepath=$2

   if [ "$output_mode" = "verbose" ]; then
      rsync -avz -e "ssh ${ssh_opts[*]}" $exclude --delete "$sourcepath" "$target:$remotepath" --info=NAME2 2>&1 | tee -a "$log_file"
      return ${PIPESTATUS[0]}
   fi

   rsync -avz -e "ssh ${ssh_opts[*]}" $exclude --delete "$sourcepath" "$target:$remotepath" --info=ALL >> "$log_file" 2>&1
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
###
if [ ! -f "$copyfolder" ]; then
   exit 0
fi

if [ ! -f "$copyfiles" ]; then
   exit 0
fi

if [ ! -f "$excludefile" ]; then
   exit 0
fi

if [ ! -e "$logpath" ]; then
   mkdir -p "$logpath"
fi

log_file="$logpath/rsync-$date.log"

case "$output_mode" in
   silent|verbose)
      ;;
   *)
      echo "ERROR: output_mode must be silent or verbose in $config_file"
      exit 1
      ;;
esac

if [ "$target" = "XXX" ]; then
    printf "\n\n***********************************************\n\nAdd Your BackupServer (FQDN) to config.cf: "
    read u_srv
   sed -i 's/^target="XXX"/target="'"$u_srv"'"/' "$config_file"
   source "$config_file"
fi

if [ "$active" != "true" ]; then
   echo "DRY RUN: active=$active in $config_file - commands are only printed, nothing is copied."
fi



### rotate logs (delete logs older than 30 days)
###
###
find "$logpath" -name "rsync-*.log" -mtime +30 -delete 2>/dev/null

### check SSH connectivity
###
###
if ! ssh -q -o BatchMode=yes "${ssh_opts[@]}" "$target" exit 2>/dev/null; then
    echo "ERROR: Cannot connect to $target - aborting"
    exit 1
fi

### initialize exclude variable
###
###
exclude=""

### get exclude list
###
###
for i in `cat $excludefile`; do

   ### chomp - the bash way :-)
   ###
   ###
   i="${i//$'\r'/$'\n'}"

   exclude="$exclude --exclude=$i"
done



### get folders to copy
###
###
no=0
for i in `cat $copyfolder`; do

  ### chomp - the bash way :-)
  ###
  ###
  i="${i//$'\r'/$'\n'}"

  ### get first character
  ###
  ###
  f="${i:0:1}"


  ### check if last character is an /
  ###
  ###
  if [ "$f" = "/" ]; then
    if [[ $i  =~ [^/]$ ]] ; then   ## determines id ending slash in missing
       echo "Missing ending slash for: $i"
       exit
    fi
  fi


  ### cut last character ( cut / )
  ###
  ###
  remotepath="${i%?}"
  sourcepath=$i


 if [ "$f" = "/" ]; then

  ### ACTION
  ###
  ###
  if [ "$active" = "true" ]; then

   if [ "$remotepath" != "" ] && [ "$sourcepath" != "" ] && [ -e $sourcepath ] && [ "$target" != "" ]; then
     run_rsync "$sourcepath" "$remotepath"
      rsync_exit=$?
     [ $rsync_exit -ne 0 ] && echo "ERROR: rsync failed for $sourcepath (exit $rsync_exit)" >> "$log_file"
   fi

  else
     echo "rsync -avz -e \"ssh ${ssh_opts[*]}\" $exclude --delete $sourcepath $target:$remotepath --info=COPY2,DEL2,NAME2,BACKUP2,REMOVE2,SKIP2 > $log_file"
  fi

 fi

 
no=$((no+1))
done






### rsync for files only
###
###
no=$((no+1))
for i in `cat $copyfiles`; do

  ### chomp - the bash way :-)
  ###
  ###
  i="${i//$'\r'/$'\n'}"

  ### get first character
  ###
  ###
  f="${i:0:1}"

  ### cut last character ( cut / )
  ###
  ###
  remotepath=$i
  sourcepath=$i


 if [ "$f" = "/" ]; then

  ### ACTION
  ###
  ###
  if [ "$active" = "true" ]; then

   if [ "$remotepath" != "" ] && [ "$sourcepath" != "" ] && [ -e $sourcepath ] && [ "$target" != "" ]; then
     run_rsync "$sourcepath" "$remotepath"
      rsync_exit=$?
     [ $rsync_exit -ne 0 ] && echo "ERROR: rsync failed for $sourcepath (exit $rsync_exit)" >> "$log_file"
   fi

  else
     echo "rsync -avz -e \"ssh ${ssh_opts[*]}\" $exclude --delete $sourcepath $target:$remotepath --info=COPY2,DEL2,NAME2,BACKUP2,REMOVE2,SKIP2 > $log_file"
  fi

 fi

 
no=$((no+1))
done


end_ts=$(date +%s)
duration=$((end_ts - start_ts))
if [ "$output_mode" = "verbose" ]; then
   echo "Runtime: $(format_duration "$duration")"
fi
echo "Runtime: $(format_duration "$duration")" >> "$log_file"

exit 0