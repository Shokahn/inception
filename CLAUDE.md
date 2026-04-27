# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Inception is a 42 school project: a multi-container WordPress stack built entirely with custom Dockerfiles (no pre-built images like `wordpress` or `mysql`). All services are based on `debian:bullseye`.

## Architecture

Three services, each in `srcs/requirements/<service>/`:

| Service | Port | Role |
|---|---|---|
| **mariadb** | 3306 | MySQL-compatible database |
| **wordpress** | 9000 | PHP-FPM application server |
| **nginx** | 80/443 | TLS-terminating reverse proxy (incomplete) |

**Startup order:** nginx depends on wordpress, which depends on mariadb. The wordpress init script polls `mysqladmin ping -h mariadb` until MariaDB is ready before proceeding.

**WordPress install location:** `/var/www/html` inside the container.  
**PHP-FPM listens on TCP port 9000** (not a Unix socket) — `init.sh` patches `/etc/php/7.4/fpm/pool.d/www.conf` at startup.

## Environment Variables

All credentials and site config live in `srcs/.env`. This file is read by docker-compose and passed into containers as environment variables. Key variables:

```
DOMAIN_NAME, MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD, MYSQL_ROOT_PASSWORD,
WP_TITLE, WP_ADMIN, WP_ADMIN_PASSWORD, WP_ADMIN_EMAIL,
WP_USER, WP_USER_PASSWORD, WP_USER_EMAIL
```

The domain is `<login>.42.fr` — requires a hosts file entry or local DNS to resolve.

## Init Script Pattern

Each service has `conf/init.sh` as its `ENTRYPOINT`. The pattern:
1. Do any first-run setup (DB creation, WordPress download/install)
2. End with `exec <daemon> -F` (foreground) so the process is PID 1.

MariaDB's init starts `mysqld_safe --skip-networking` temporarily, runs SQL setup, shuts it down, then `exec mysqld_safe` as the final process.

WordPress's init is idempotent — skips WP download/install if `wp-login.php` already exists, so volume-mounted data survives container restarts.

## What's Missing / In Progress

- **Nginx** — `srcs/requirements/nginx/` directory exists but has no Dockerfile or config yet. It needs an SSL config proxying to `wordpress:9000`.
- **docker-compose.yml** — the orchestration file does not exist yet. It needs to define the three services, a shared network, volumes for MariaDB data and WordPress files, and inject `srcs/.env`.
- **SSL certificates** — Nginx will need TLS certs (self-signed via openssl, or via a certs volume).

## Build Commands

```bash
# Build individual images (run from repo root)
docker build -f srcs/requirements/mariadb/Dockerfile -t inception-mariadb srcs/requirements/mariadb
docker build -f srcs/requirements/wordpress/Dockerfile -t inception-wordpress srcs/requirements/wordpress

# Once docker-compose.yml exists:
docker-compose -f srcs/docker-compose.yml up --build
docker-compose -f srcs/docker-compose.yml down -v   # -v removes volumes too
```