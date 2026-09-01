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

The weekly `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned SonarQube and Traefik versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **Change the admin password immediately** — the first login forces it; don't postpone the first login.
- [ ] **Strong database password** — 24+ random characters.
- [ ] **Regenerate the Traefik dashboard hash** — never ship the placeholder.
- [ ] **Host-mount the backup volumes** for disaster recovery.
- [ ] **Size the host for analysis load** — SonarQube wants 4 GB+ RAM; the embedded Elasticsearch is the hungry part.

## Backups and restore

The `backups` container runs a `pg_dump | gzip` + `tar.gz`-of-data → prune → sleep loop (defaults: 30-minute warm-up, 24-hour interval, 7-day retention). Restore with the interactive scripts (`chmod +x *.sh` once): `./sonarqube-restore-database.sh`, then `./sonarqube-restore-application-data.sh`.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/sonarqube-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every Monday at 06:00 UTC: shellcheck + actionlint, Trivy scans of all three pinned images, the weekly freshness check, and a deploy-and-test job that boots the stack with ephemeral credentials and requires `/api/system/status` to report `UP` through Traefik.

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
