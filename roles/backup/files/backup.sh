#!/bin/bash

# Home root directory
# HOME_DIR=""

BACKUP_DIR="$HOME_DIR/backup"

# Some credentials for mysql/maria_db
# SHOW DATABASES
# SELECT
# LOCK TABLES
# RELOAD
MYSQL_USER='backup'

# Folders to ignore and patterns to ignore
IGNORE_FOLDERS="(mantis|public|photo)"
IGNORE_PATTERNS="(rel\-|prod|beta)"

# Create a backup folder for each run
TIMESTAMP=$(date +"%F_%s")
THIS_BACKUP_DIR="$BACKUP_DIR/$TIMESTAMP"
mkdir "$THIS_BACKUP_DIR"

# FTP Stuff
HOSTNAME=`hostname`
FTP_HOST="dedibackup-dc2.online.net"

BACKED_UP="NO"

MYSQL=`type mysql >/dev/null 2>&1 && echo "ok" || echo "nok"`
if [ "$MYSQL" = "ok" ]; then

  # Retrieves all databases
  databases=`mysql --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema)"`
  
  if [ `echo "$databases" | wc -l` -gt 2 ]; then

    echo "Backing up databases :"
    mkdir "$THIS_BACKUP_DIR/mysql" 

    # Dumps everything
    for db in $databases; do
      ([  "$db" = "mysql" ] || [ "$db" = "performance_schema" ]) && continue
      printf " - $db .."
      mysqldump --single-transaction --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | gzip --best > "$THIS_BACKUP_DIR/mysql/$db.sql.gz"
      echo "done."
    done

    BACKED_UP="YES"

  fi

fi

folders_count=`find $HOME_DIR/www/ -maxdepth 1 -mindepth 1 -type d | wc -l`

if [ "$folders_count" -gt 1 ]; then # ./ counts as one ...

  # Retrieves all folders to backup
  folders=`ls -d $HOME_DIR/www/*/*/ | grep -Ev "$IGNORE_FOLDERS" | grep -Ev "\w\/$IGNORE_PATTERNS"`

  if [ `echo "$folders" | wc -l` -gt 0 ]; then

    # if folders length > 0...
    echo "Backing up ugc folders :"
    mkdir "$THIS_BACKUP_DIR/ugc" 

    # Backup files
    for folder in $folders; do 
      printf " - $folder .."
      mkdir -p $THIS_BACKUP_DIR/ugc/$(basename $(dirname $folder))
      find $folder -type d -o -size -512M -print0 | xargs -0 tar cpzvf $THIS_BACKUP_DIR/ugc/$(basename $(dirname $folder))/$(basename $folder).tar
      echo "done."
    done

    BACKED_UP="YES"

  fi

fi

# Update the "last" symlink
if [ "$BACKED_UP" = "YES" ]; then
  ln -sfn "$THIS_BACKUP_DIR" "$BACKUP_DIR/last"

  # create a tar of the folder to sync with ftp

  # Syncs last backup with a FTP if any
  echo "Syncing with FTP :"
  ftp $FTP_HOST <<EOF
  binary
  passive
  cd "$HOSTNAME"
  put "| tar cvf - $THIS_BACKUP_DIR" $TIMESTAMP.tar
  quit
EOF
  echo "Backed up. Exiting."

else
  rmdir "$THIS_BACKUP_DIR"
  echo "Nothing to be done. Exiting."
fi
