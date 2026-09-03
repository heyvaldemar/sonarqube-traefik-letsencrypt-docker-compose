# SonarQube + Traefik + Let's Encrypt — Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/sonarqube-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/sonarqube-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository deploys **SonarQube Community Build** — static code analysis for 30+ languages — behind **Traefik** with automatic **Let's Encrypt TLS**, backed by **PostgreSQL 17**, with scheduled **backups** (database + data volume) and companion **restore scripts**.

📙 Full narrative installation guide on the blog: [heyvaldemar.com/install-sonarqube-using-docker-compose/](https://www.heyvaldemar.com/install-sonarqube-using-docker-compose/).

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/sonarqube-traefik-letsencrypt-docker-compose
cd sonarqube-traefik-letsencrypt-docker-compose

# 2. Create the two Docker networks the stack expects
docker network create traefik-network
docker network create sonarqube-network

# 3. Copy the environment template and fill in required values
cp .env.example .env
$EDITOR .env
# ^ Required: SONARQUBE_DB_PASSWORD, SONARQUBE_HOSTNAME,
#   TRAEFIK_HOSTNAME, TRAEFIK_ACME_EMAIL, TRAEFIK_BASIC_AUTH.

# 4. Deploy
docker compose -f sonarqube-traefik-letsencrypt-docker-compose.yml -p sonarqube up -d
```

First start takes a few minutes: SonarQube runs its database migration and boots the embedded Elasticsearch before `/api/system/status` reports `UP`. Log in with `admin`/`admin` — SonarQube forces a password change immediately.

### What success looks like

```bash
docker compose -f sonarqube-traefik-letsencrypt-docker-compose.yml -p sonarqube ps
curl -fsk "https://${SONARQUBE_HOSTNAME}/api/system/status"   # {"status":"UP",...}
```

### Common first-deploy issues

- **Cert issuance fails.** DNS hasn't propagated or port 80 isn't reachable from the internet.
- **404 through the proxy while logs look fine.** The SonarQube container is still starting or unhealthy — Traefik only routes to healthy containers. `docker ps` shows the health state.
- **Elasticsearch bootstrap errors.** This template sets `-Dnode.store.allow_mmap=false`, so the usual `vm.max_map_count` requirement does not apply.
- **Networks not found.** Step 2 was skipped.

## Supply chain trust

Three images — [`traefik`](https://hub.docker.com/_/traefik), [`sonarqube`](https://hub.docker.com/_/sonarqube), [`postgres`](https://hub.docker.com/_/postgres) — pinned to `tag@sha256:<digest>` as interpolation defaults in the compose `x-images` block. `git pull` alone delivers the tested combination; an `*_IMAGE_TAG` variable in `.env` overrides deliberately.

The daily `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned SonarQube and Traefik versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **Change the admin password immediately** — the first login forces it; don't postpone the first login.
- [ ] **Strong database password** — 24+ random characters.
- [ ] **Regenerate the Traefik dashboard hash** — never ship the placeholder.
- [ ] **Host-mount the backup volumes** for disaster recovery.
- [ ] **Size the host for analysis load** — SonarQube wants 4 GB+ RAM; the embedded Elasticsearch is the hungry part.

## Backups and restore

The `backups` container runs a `pg_dump | gzip` + `tar.gz`-of-data → prune → sleep loop (defaults: 30-minute warm-up, 24-hour interval, 7-day retention). Restore with the interactive scripts (`chmod +x *.sh` once): `./sonarqube-restore-database.sh`, then `./sonarqube-restore-application-data.sh`.

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults — the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `TRAEFIK_MEMORY_LIMIT=512m`) and the override survives every `git pull`. If a service is OOM-killed under real load, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise its `_MEMORY_LIMIT` and recreate.

## Container hardening

Every service runs with `security_opt: no-new-privileges:true`, so a process cannot gain privileges through setuid binaries even if it escapes its initial capability set. Infrastructure containers (the reverse proxy, databases, caches, backups) run with `cap_drop: [ALL]` and add back only what their entrypoints need: `NET_BIND_SERVICE` for Traefik to bind :80/:443, `CHOWN`/`SETUID`/`SETGID` (and friends) for database images to own their data directory and drop to their service user. Application containers keep the default capability set on purpose: upstream images assume it, and a wrong guess there is a boot loop in production rather than a hardening win. CI boots the stack under exactly these settings on every push, so what ships is what was tested.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/sonarqube-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC: shellcheck + actionlint, Trivy scans of all three pinned images, the weekly freshness check, and a deploy-and-test job that boots the stack with ephemeral credentials and requires `/api/system/status` to report `UP` through Traefik.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the HTTPS smoke. The scenario that matters most is the restore roundtrip: insert a marker row, restore the earliest backup, assert the marker is gone — a backup that cannot be restored fails the build. Run it yourself against a running deployment with short intervals in `.env` (`BACKUP_INIT_SLEEP=15s`, `BACKUP_INTERVAL=60s`):

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

It stops the database container briefly to prove failure detection — run it on a staging copy, not on production.

## Security Notes

- Credentials are read from `.env` at deploy time; `.env` is gitignored and compose fails fast on missing required variables.
- **Pre-rotation advisory.** Releases before v1.0.0 (2026-09-01) shipped a tracked `.env` with a generated-looking database password and SMTP relay credentials. Rotate both if your deployment reused them.
- SMTP is off by default; PostgreSQL listens only on the internal network.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** — Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
