#!/bin/bash

PYTHONHOME=/app/vendor/awscli/
DBNAME=""
EXPIRATION="30"
Green='\033[0;32m'
EC='\033[0m'
FILENAME=`date +%Y%m%d_%H_%M`

# terminate script on any fails
set -e

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -exp|--expiration)
    EXPIRATION="$2"
    shift
    ;;
    -db|--dbname)
    DBNAME="$2"
    shift
    ;;
esac
shift
done

if [[ -z "$DBNAME" ]]; then
  echo "Missing DBNAME variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_AWS_ACCESS_KEY_ID" ]]; then
  echo "Missing DB_BACKUP_AWS_ACCESS_KEY_ID variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_AWS_SECRET_ACCESS_KEY" ]]; then
  echo "Missing DB_BACKUP_AWS_SECRET_ACCESS_KEY variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_AWS_DEFAULT_REGION" ]]; then
  echo "Missing DB_BACKUP_AWS_DEFAULT_REGION variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_S3_BUCKET_PATH" ]]; then
  echo "Missing DB_BACKUP_S3_BUCKET_PATH variable"
  exit 1
fi
if [[ -z "$DBURL_FOR_BACKUP" ]] ; then
  if [[ -z "$DB_BACKUP_HOST" ]] ; then
    echo "Missing DB_BACKUP_HOST variable"
    exit 1
  fi
  if [[ -z "$DB_BACKUP_USER" ]] ; then
    echo "Missing DB_BACKUP_USER variable"
    exit 1
  fi
  if [[ -z "$DB_BACKUP_PASSWORD" ]] ; then
    echo "Missing DB_BACKUP_PASSWORD variable"
    exit 1
  fi
  if [[ -z "$DB_BACKUP_DATABASE" ]] ; then
    echo "Missing DB_BACKUP_DATABASE variable"
    exit 1
  fi
fi

printf "${Green}Start dump${EC}"

if [[ $DB_BACKUP_HOST ]]; then
  mysqldump --no-tablespaces -h $DB_BACKUP_HOST -p$DB_BACKUP_PASSWORD -u$DB_BACKUP_USER $DB_BACKUP_DATABASE | gzip > /tmp/"${DBNAME}_${FILENAME}".gz
elif [[ $DBURL_FOR_BACKUP = postgres* ]]; then
  pg_dump $DBURL_FOR_BACKUP | gzip > /tmp/"${DBNAME}_${FILENAME}".gz
else
  echo "Unknown database URL protocol. Must be mysql, mysql2 or postgres"
  exit 1;
fi;

#EXPIRATION_DATE=$(date -v +"2d" +"%Y-%m-%dT%H:%M:%SZ") #for MAC
EXPIRATION_DATE=$(date -d "$EXPIRATION days" +"%Y-%m-%dT%H:%M:%SZ")

printf "${Green}Move dump to AWS${EC}"
AWS_ACCESS_KEY_ID=$DB_BACKUP_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$DB_BACKUP_AWS_SECRET_ACCESS_KEY /app/vendor/bin/aws --region $DB_BACKUP_AWS_DEFAULT_REGION s3 cp /tmp/"${DBNAME}_${FILENAME}".gz s3://$DB_BACKUP_S3_BUCKET_PATH/$DBNAME/"${DBNAME}_${FILENAME}".gz --expires $EXPIRATION_DATE

# cleaning after all
rm -rf /tmp/"${DBNAME}_${FILENAME}".gz
