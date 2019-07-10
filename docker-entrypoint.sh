#!/bin/bash
set -e

if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${USER_NAME:-default}:x:$(id -u):0:${USER_NAME:-default} user:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi

if [ "$1" = 'geoserver' ]; then
    id
    whoami
    # start tomcat
    exec env JAVA_OPTS="${JAVA_OPTS}" catalina.sh run
fi

