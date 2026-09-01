# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.0.0] - 2026-09-01

First semver release. Brings this template to the fleet standard established
in [keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose)
v1.2.0.

### Changed

- **SonarQube 26.2 → 26.8.0 community build**, **Traefik 3.2 → 3.7** —
  3.7 talks to Docker Engine 29 natively, so the `DOCKER_API_VERSION=1.47`
  workaround is gone. PostgreSQL stays on 17-alpine, now digest-pinned.
- **All images pinned by `tag@sha256:digest`** in the compose `x-images`
  block; `.env` now carries only secrets and deliberate overrides.
- **SMTP is off by default** — set the `SONARQUBE_SMTP_*` variables to
  enable outgoing mail.

### Fixed

- **The container healthcheck could never pass**: it called `wget`, which
  the sonarqube image does not ship (it has `curl` only). A permanently
  unhealthy container is removed from Traefik load balancing, so every
  request through the proxy returned 404 while SonarQube itself was
  operational. The healthcheck now uses `curl`.
- Backup-loop variables are `$$`-escaped so the container shell resolves
  them at runtime; shellcheck findings in both restore scripts.

### Security

- **Credentials untracked from git.** The tracked `.env` carried a
  generated-looking database password and SMTP relay credentials —
  rotate both if reused.

### Added

- **Deployment Verification workflow**: shellcheck + actionlint; Trivy
  scans of all three pinned images; weekly `check-pin-freshness` (digest
  drift + SonarQube community-build lag + Traefik release lag); and a
  deploy-and-test job that boots the stack and requires
  `/api/system/status` to report `UP` through Traefik.

[Unreleased]: https://github.com/heyvaldemar/sonarqube-traefik-letsencrypt-docker-compose/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/heyvaldemar/sonarqube-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
