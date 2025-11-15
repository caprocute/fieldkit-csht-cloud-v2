#!/bin/bash

set -xe

sql_file=$1

if [ -z $sql_file ]; then
	echo "sql file is required"
	exit 2
fi

if [ ! -f $sql_file ]; then
	echo "sql file is required"
	exit 2
fi

DB_HOST=$FIELDKIT_DB_HOST
if [ -z "$DB_HOST" ]; then
	DB_HOST=127.0.0.1
fi

DB_USER=$FIELDKIT_DB_USER
if [ -z "$DB_USER" ]; then
	DB_USER=fieldkit
fi

DB_PORT=$FIELDKIT_DB_PORT
if [ -z "$DB_PORT" ]; then
	DB_PORT=5432
fi

psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'fk';"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c "DROP DATABASE fk;" || true
psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c "DROP ROLE fieldkit;" || true
psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c "DROP ROLE fk;" || true
psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c "CREATE ROLE fieldkit;" || true
psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c "CREATE ROLE fk;" || true
psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c "CREATE DATABASE fk;"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER postgres -c 'ALTER DATABASE fk SET search_path TO "\$user", fieldkit, public;'
psql -h $DB_HOST -p $DB_PORT -U $DB_USER fk -c "CREATE EXTENSION postgis;"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER fk -c "CREATE EXTENSION timescaledb WITH VERSION '2.15.3';"

if [ "${sql_file: -4}" == ".bz2" ]; then
	bunzip2 -c $sql_file | psql -h $DB_HOST -p $DB_PORT -U $DB_USER fk
elif [ "${sql_file: -3}" == ".xz" ]; then
	xz -dc $sql_file | psql -h $DB_HOST -p $DB_PORT -U $DB_USER fk
elif [ "${sql_file: -4}" == ".sql" ]; then
	psql -h $DB_HOST -p $DB_PORT -U $DB_USER fk < $sql_file
fi

make migrate-up
