#!/usr/bin/env bash
# sonarqube-migrate-if-asked.sh - start SonarQube's database migration when it
# waits for one, as the README's Updating section tells an operator to.
#
# SonarQube migrates a fresh database by itself. On a database an older
# release wrote, it waits in maintenance (DB_MIGRATION_NEEDED) until someone
# starts the migration: SonarSource keeps that step manual on purpose. Until
# then the container is not healthy, its healthcheck waits for UP, and
# Traefik does not route to it, so this asks from inside the container. Two
# checks meet that database: the deployment check after an upgrade, and the
# clean-machine drill after it restores the previous release's database onto
# this one, which on 15 October waited 15 minutes for a migration nobody
# started.
#
# Reads DOCKER_COMPOSE_FILE and COMPOSE_PROJECT_NAME, as both workflows set them.
set -euo pipefail
: "${DOCKER_COMPOSE_FILE:?}" "${COMPOSE_PROJECT_NAME:?}"
sq() { docker compose -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" exec -T sonarqube "$@"; }
for _ in $(seq 1 60); do
  status="$(sq curl -fsS http://localhost:9000/api/system/status 2>/dev/null | jq -r '.status' 2>/dev/null || true)"
  case "$status" in
    DB_MIGRATION_NEEDED)
      echo "SonarQube asks for its database migration; starting it as the README says"
      sq curl -fsS -X POST http://localhost:9000/api/system/migrate_db
      echo
      exit 0
      ;;
    UP | DB_MIGRATION_RUNNING)
      echo "status $status: no migration to start"
      exit 0
      ;;
  esac
  sleep 10
done
echo "SonarQube never reported a status; the wait that follows will say why"
