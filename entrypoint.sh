#!/bin/sh

## start cronjobs for the queue
echo -e "Starting cron jobs."
su-exec root crond

echo -e "Starting supervisord."
exec "$@"
