#!/bin/bash

SONARQUBE_CONTAINER=$(docker ps -aqf "name=sonarqube_sonarqube")
SONARQUBE_BACKUPS_CONTAINER=$(docker ps -aqf "name=sonarqube_backups")

echo "--> All available application data backups:"

for entry in $(docker container exec -it $SONARQUBE_BACKUPS_CONTAINER sh -c "ls /srv/sonarqube-application-data/backups/")
do
  echo "$entry"
done

echo "--> Copy and paste the backup name from the list above to restore application data and press [ENTER]
--> Example: sonarqube-application-data-backup-YYYY-MM-DD_hh-mm.tar.gz"
echo -n "--> "

read SELECTED_APPLICATION_BACKUP

echo "--> $SELECTED_APPLICATION_BACKUP was selected"

echo "--> Stopping service..."
docker stop $SONARQUBE_CONTAINER

echo "--> Restoring application data..."
docker exec -it $SONARQUBE_BACKUPS_CONTAINER sh -c "rm -rf /opt/sonarqube/data/* && tar -zxpf /srv/sonarqube-application-data/backups/$SELECTED_APPLICATION_BACKUP -C /"
echo "--> Application data recovery completed..."

echo "--> Starting service..."
docker start $SONARQUBE_CONTAINER