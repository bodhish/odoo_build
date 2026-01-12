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
    # `git` required packages
    git \
    git-man \
    less \
    libcurl3-gnutls \
    libedit2 \
    liberror-perl \
    libfido2-1 \
    libxmuu1 \
    openssh-client \
    patch \
    xauth \
    && rm -rf /var/lib/apt/lists/*


COPY --chown=odoo:odoo requirements.txt /tmp/requirements.txt

RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt


    
COPY --chown=odoo:odoo addons_config.sh /
RUN chmod +x /addons_config.sh
COPY --chown=odoo:odoo third-party-addons.txt /
RUN /addons_config.sh


COPY --chown=odoo:odoo extra_addons /mnt/extra-addons

USER odoo