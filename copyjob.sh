#!/bin/bash

### Vars
###
###
script=$(readlink -f $0)
path=`dirname $script`
logpath="/var/log/rsync"
copyfile="$path/list.cf"
excludefile="$path/exclude.cf"
host="srv002.bit-worker.com"
active="false"



### check
###
###
if [ ! -f "$copyfile" ]; then
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
for i in `cat $copyfile`; do

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
files="/etc/motd /etc/crontab /etc/passwd /etc/shadow /etc/pam.d/vsftpd /etc/cron.daily/webalizer*"
target="/etc"
if [ "$active" = "true" ]; then
    rsync -avz $exclude --delete $files $host:$target --log-file=$logpath/rsync-files.log
  else
    echo "rsync -avz $exclude --delete $files $host:$target --log-file=$logpath/rsync-files.log"
fi

exit 0
