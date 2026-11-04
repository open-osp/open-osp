#!/bin/bash
#
# Run the one-off health check container against the running stack.
#
# Both compose files are passed so Compose sees the whole project and
# doesn't flag the main services (or this container) as orphans.
# --rm removes the container after it exits; --no-deps leaves the
# running stack untouched.

exec docker compose -f docker-compose.yml -f docker-compose.admin.yml run --rm --no-deps health "$@"
