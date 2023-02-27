#!/usr/bin/env bash

set -o nounset
set -o pipefail
set -o errexit

BIN_PATH=/app/bin/prod

if [[ ! -f "/var/lib/pillminder/pillminder.db" ]]; then
	# We don't want to attempt to startup unless we know the database is here. This prevents accidentally
	# keeping the sqlite database in the container
	echo "No pillminder database was found. Refusing to run" >&2
	exit 1
fi

echo "Running migrations..." >&2
"$BIN_PATH" eval "Pillminder.Release.migrate"

echo "Starting the application..." >&2
exec "$BIN_PATH" start
