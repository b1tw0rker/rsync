#!/bin/bash

### Version: 1.0.76
### Build date: 11.05.2021
### (C) 2021 by Dipl. Wirt.-Ing. Nick Herrmann
### This program is WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
###
###



### Vars
###
###
script=$(readlink -f $0)
path=`dirname $script`
logpath="/var/log/rsync"
copyfolder="$path/folder.cf"
copyfiles="$path/files.cf"
excludefile="$path/exclude.cf"
host="XXX"
active="false"



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
   mkdir /var/log/rsync
fi

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



### get copy list
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

  ### cut last character ( cut / )
  ###
  ###
  target="${i%?}"
  local=$i


 if [ "$f" = "/" ]; then

  ### ACTION
  ###
  ###
  if [ "$active" = "true" ]; then

   if [ "$target" != "" ] && [ "$local" != "" ] && [ -e $local ] && [ "$host" != "" ]; then
      rsync -avz $exclude --delete $local $host:$target --log-file=/var/log/rsync/rsync-$no.log
   fi

  else

    echo "rsync -avz $exclude --delete $local $host:$target --log-file=$logpath/rsync-$no.log"

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
  target=$i
  local=$i


 if [ "$f" = "/" ]; then

  ### ACTION
  ###
  ###
  if [ "$active" = "true" ]; then

   if [ "$target" != "" ] && [ "$local" != "" ] && [ -e $local ] && [ "$host" != "" ]; then
      rsync -avz $exclude --delete $local $host:$target --log-file=/var/log/rsync/rsync-$no.log
   fi

  else

    echo "rsync -avz $exclude --delete $local $host:$target --log-file=$logpath/rsync-$no.log"

  fi

 fi

 
no=$((no+1))
done









exit 0


