#!/bin/bash

### Version: 1.0.1
### Build date: 11.05.2021
### (C) 2021 by Dipl. Wirt.-Ing. Nick Herrmann
### This program is WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
###
###

set -u

script=$(readlink -f $0)
path=`dirname $script`
source $path/config.cf





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

if [ "$target" = "XXX" ]; then
    printf "\n\n***********************************************\n\nAdd Your BackupServer (FQDN) to config.cf: "
    read u_srv
    sed -i 's/^target="XXX"/target="'"$u_srv"'"/' config.cf
    source $path/config.cf
fi



### rotate logs (delete logs older than 30 days)
###
###
find "$logpath" -name "rsync-*.log" -mtime +30 -delete 2>/dev/null

### check SSH connectivity
###
###
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$target" exit 2>/dev/null; then
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
      rsync -avz $exclude --delete $sourcepath $target:$remotepath  --info=ALL >> $logpath/rsync-$date.log
      rsync_exit=$?
      [ $rsync_exit -ne 0 ] && echo "ERROR: rsync failed for $sourcepath (exit $rsync_exit)" >> $logpath/rsync-$date.log
   fi

  else
    echo "rsync -avz $exclude --delete $sourcepath $target:$remotepath --info=COPY2,DEL2,NAME2,BACKUP2,REMOVE2,SKIP2 > $logpath/rsync-$date.log"
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
      rsync -avz $exclude --delete $sourcepath $target:$remotepath  --info=ALL >> $logpath/rsync-$date.log
      rsync_exit=$?
      [ $rsync_exit -ne 0 ] && echo "ERROR: rsync failed for $sourcepath (exit $rsync_exit)" >> $logpath/rsync-$date.log
   fi

  else
    echo "rsync -avz $exclude --delete $sourcepath $target:$remotepath --info=COPY2,DEL2,NAME2,BACKUP2,REMOVE2,SKIP2 > $logpath/rsync-$date.log"
  fi

 fi

 
no=$((no+1))
done


exit 0