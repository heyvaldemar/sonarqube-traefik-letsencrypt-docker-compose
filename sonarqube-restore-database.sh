#!/bin/bash

SONARQUBE_CONTAINER=$(docker ps -aqf "name=sonarqube_sonarqube")
SONARQUBE_BACKUPS_CONTAINER=$(docker ps -aqf "name=sonarqube_backups")

echo "--> All available database backups:"

for entry in $(docker container exec -it $SONARQUBE_BACKUPS_CONTAINER sh -c "ls /srv/sonarqube-postgres/backups/")
do
  echo "$entry"
done

echo "--> Copy and paste the backup name from the list above to restore database and press [ENTER]
--> Example: sonarqube-postgres-backup-YYYY-MM-DD_hh-mm.gz"
echo -n "--> "

read SELECTED_DATABASE_BACKUP

echo "--> $SELECTED_DATABASE_BACKUP was selected"

echo "--> Stopping service..."
docker stop $SONARQUBE_CONTAINER

echo "--> Restoring database..."
docker exec -it $SONARQUBE_BACKUPS_CONTAINER sh -c 'PGPASSWORD="$(echo $POSTGRES_PASSWORD)" dropdb -h postgres -p 5432 sonarqubedb -U sonarqubedbuser \
&& PGPASSWORD="$(echo $POSTGRES_PASSWORD)" createdb -h postgres -p 5432 sonarqubedb -U sonarqubedbuser \
&& PGPASSWORD="$(echo $POSTGRES_PASSWORD)" gunzip -c /srv/sonarqube-postgres/backups/'$SELECTED_DATABASE_BACKUP' | PGPASSWORD=$(echo $POSTGRES_PASSWORD) psql -h postgres -p 5432 sonarqubedb -U sonarqubedbuser'
echo "--> Database recovery completed..."

echo "--> Starting service..."
docker start $SONARQUBE_CONTAINER