#!/bin/bash

set -e

# Set `java` command if needed
if [ "$1" = "" -o "${1:0:1}" = "-" ]; then
  set -- java $JAVA_OPTS -cp /var/wiremock/lib/*:/var/wiremock/extensions/* wiremock.Run "$@"
fi

exec "$@" --port=8000 $WIREMOCK_OPTIONS