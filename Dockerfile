# Odoo Enterprise Base Image
# Compatible with official odoo:19.0 image structure
#
# Build with:
#   docker build --build-arg ODOO_SOURCE_URL=https://your-s3-url/odoo.tar.gz -t odoo-enterprise:19.0 .
#
# Optionally provide SHA for verification:
#   docker build --build-arg ODOO_SOURCE_URL=... --build-arg ODOO_SOURCE_SHA=abc123... -t odoo-enterprise:19.0 .
#
# Use as base image:
#   FROM odoo-enterprise:19.0

# ============================================
# Stage 1: Download and extract source
# ============================================
FROM debian:bookworm-slim AS downloader

ARG ODOO_SOURCE_URL
ARG ODOO_SOURCE_SHA

# Validate that source URL is provided
RUN if [ -z "$ODOO_SOURCE_URL" ]; then \
        echo "ERROR: ODOO_SOURCE_URL build argument is required" && exit 1; \
    fi

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Download and optionally verify source
RUN echo "Downloading Odoo source from: $ODOO_SOURCE_URL" \
    && curl -fSL "$ODOO_SOURCE_URL" -o odoo.tar.gz \
    && if [ -n "$ODOO_SOURCE_SHA" ]; then \
           echo "$ODOO_SOURCE_SHA odoo.tar.gz" | sha256sum -c -; \
       else \
           echo "WARNING: No ODOO_SOURCE_SHA provided, skipping verification"; \
       fi \
    && mkdir -p /usr/lib/python3/dist-packages \
    && tar -xzf odoo.tar.gz -C /usr/lib/python3/dist-packages --strip-components=1 \
    && if [ -f "/usr/lib/python3/dist-packages/odoo/init.py" ]; then \
           mv /usr/lib/python3/dist-packages/odoo/init.py /usr/lib/python3/dist-packages/odoo/__init__.py; \
       fi \
    && rm odoo.tar.gz

# ============================================
# Stage 2: Build Python dependencies
# ============================================
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-full \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-dev \
        # Build dependencies for pip packages
        build-essential \
        libpq-dev \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Odoo source to get requirements.txt
COPY --from=downloader /usr/lib/python3/dist-packages/requirements.txt /tmp/requirements.txt

# Install Python packages to a separate directory we can copy
RUN pip3 install --no-cache-dir --prefix=/install --break-system-packages \
    -r /tmp/requirements.txt

# ============================================
# Stage 3: Final runtime image
# ============================================
FROM debian:bookworm-slim

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG=C.UTF-8

ARG ODOO_VERSION=19.0
ARG ODOO_RELEASE=20260106

LABEL maintainer="Odoo Enterprise" \
      version="${ODOO_VERSION}" \
      release="${ODOO_RELEASE}"

# Install runtime dependencies only (no build tools!)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        node-less \
        npm \
        python3-full \
        python3-pip \
        python3-setuptools \
        xz-utils \
        # Runtime libraries for Python packages
        libpq5 \
        libldap-2.5-0 \
        libsasl2-2 \
        libssl3 \
        libxml2 \
        libxslt1.1 \
        libjpeg62-turbo \
        libmagic1 \
        # wkhtmltopdf dependencies
        fontconfig \
        libfreetype6 \
        libpng16-16 \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
        xfonts-75dpi \
        xfonts-base \
    && rm -rf /var/lib/apt/lists/*

# Install wkhtmltopdf
RUN apt-get update \
    && apt-get install -y --no-install-recommends wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

# Install latest postgresql-client from official PostgreSQL repo
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss
RUN npm install -g rtlcss \
    && npm cache clean --force

# Create odoo user and group (matching official image)
RUN groupadd -g 101 odoo \
    && useradd -u 101 -g odoo -G odoo -d /var/lib/odoo -s /bin/bash odoo

# Copy pre-built Python packages from builder stage
COPY --from=builder /install /usr/local

# Copy Odoo source from downloader stage
COPY --from=downloader /usr/lib/python3/dist-packages /usr/lib/python3/dist-packages

# Create odoo binary/wrapper
RUN echo '#!/usr/bin/env python3' > /usr/bin/odoo \
    && echo 'import sys; sys.path.insert(0, "/usr/lib/python3/dist-packages")' >> /usr/bin/odoo \
    && echo 'import odoo; odoo.cli.main()' >> /usr/bin/odoo \
    && chmod +x /usr/bin/odoo \
    && ln -s /usr/bin/odoo /usr/bin/odoo-bin

# Copy entrypoint and wait-for-psql scripts
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py
COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh /usr/local/bin/wait-for-psql.py

# Create directories and set permissions
RUN mkdir -p /etc/odoo /var/lib/odoo /mnt/extra-addons \
    && chown -R odoo:odoo /etc/odoo /var/lib/odoo /mnt/extra-addons

# Copy default config
COPY odoo.conf /etc/odoo/odoo.conf
RUN chown odoo:odoo /etc/odoo/odoo.conf \
    && chmod 640 /etc/odoo/odoo.conf

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

EXPOSE 8069 8071 8072

ENV ODOO_RC=/etc/odoo/odoo.conf

USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
