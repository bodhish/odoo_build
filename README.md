# Odoo Enterprise Docker Base Image

Build a Docker base image for Odoo Enterprise that is **compatible with the official `odoo:19.0` image**.

Use this as a drop-in replacement for `FROM odoo:19.0` in your Dockerfiles.

## Quick Start

### 1. Configure the S3 URL

```bash
cp env.example .env
```

Edit `.env` and set your S3 URL:

```env
ODOO_SOURCE_URL=https://your-bucket.s3.amazonaws.com/odoo_19.0+e.20260106.tar.gz
```

### 2. Build the Base Image

```bash
chmod +x build.sh
./build.sh
```

### 3. Use as Base Image

```dockerfile
FROM odoo-enterprise:19.0
USER root

# Install additional packages
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install additional Python packages
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

# Copy custom addons
COPY --chown=odoo:odoo extra_addons /mnt/extra-addons

USER odoo
```

## Image Structure (Compatible with Official Odoo)

| Path | Description |
|------|-------------|
| `/usr/lib/python3/dist-packages/odoo` | Odoo source code |
| `/usr/bin/odoo` | Odoo executable |
| `/etc/odoo/odoo.conf` | Default configuration |
| `/var/lib/odoo` | Data directory (filestore) |
| `/mnt/extra-addons` | Custom addons mount point |
| `/entrypoint.sh` | Docker entrypoint |

## Build Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `ODOO_SOURCE_URL` | Yes | - | Public URL to Odoo Enterprise tarball |
| `ODOO_VERSION` | No | 19.0 | Odoo version |
| `ODOO_RELEASE` | No | 20260106 | Release date |

## Environment Variables (Runtime)

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | db | PostgreSQL host |
| `PORT` | 5432 | PostgreSQL port |
| `USER` | odoo | Database user |
| `PASSWORD` | odoo | Database password |
| `PASSWORD_FILE` | - | Read password from file (Docker secrets) |
| `ODOO_RC` | /etc/odoo/odoo.conf | Config file path |

## Example: Your Deployment Dockerfile

```dockerfile
FROM odoo-enterprise:19.0
USER root

ARG ODOO_TAG
ARG ROOT_PATH
ARG LOG_PATH
ARG ENTERPRISE_USER
ARG ENTERPRISE_ADDONS
ARG GITHUB_USER
ARG THIRD_PARTY_ADDONS
ARG ODOO_RC
ARG USE_REDIS
ARG USE_S3
ARG USE_SENTRY

ENV ODOO_TAG=${ODOO_TAG:-19.0} \
    LOG_PATH=${LOG_PATH} \
    ENTERPRISE_USER=${ENTERPRISE_USER} \
    ENTERPRISE_ADDONS=${ENTERPRISE_ADDONS:-/mnt/enterprise-addons} \
    GITHUB_USER=${GITHUB_USER} \
    THIRD_PARTY_ADDONS=${THIRD_PARTY_ADDONS:-/mnt/third-party-addons} \
    ODOO_RC=${ODOO_RC} \
    USE_REDIS=${USE_REDIS} \
    USE_S3=${USE_S3} \
    USE_SENTRY=${USE_SENTRY}

RUN apt-get update && apt-get install -y \
    zip \
    unzip \
    git \
    git-man \
    less \
    patch \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=odoo:odoo requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt

COPY --chown=odoo:odoo addons_config.sh /
COPY --chown=odoo:odoo third-party-addons.txt /
RUN /addons_config.sh

COPY --chown=odoo:odoo extra_addons /mnt/extra-addons

USER odoo
```

## Volumes

| Path | Purpose |
|------|---------|
| `/var/lib/odoo` | Odoo data (filestore, sessions) |
| `/mnt/extra-addons` | Custom addons |

## Pushing to Registry

```bash
# Tag for your registry
docker tag odoo-enterprise:19.0 your-registry.com/odoo-enterprise:19.0

# Push
docker push your-registry.com/odoo-enterprise:19.0
```

## Files

```
docker-base/
├── Dockerfile              # Multi-stage build (official odoo compatible)
├── entrypoint.sh           # Entrypoint (official odoo compatible)
├── wait-for-psql.py        # Wait for PostgreSQL script
├── odoo.conf               # Default Odoo configuration
├── docker-compose.yml      # Run the built image
├── docker-compose.build.yml # Build using docker-compose
├── build.sh                # Build helper script
├── env.example             # Example environment file
└── README.md               # This file
```
