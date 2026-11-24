#!/bin/sh

# Protect against buggy runc in docker <20.10.6 causing problems in with Alpine >= 3.14
if [ ! -x /bin/sh ]; then
  echo "Executable test for /bin/sh failed. Your Docker version is too old to run Alpine 3.14+ and Gitea. You must upgrade Docker.";
  exit 1;
fi

# Prepare git folder
mkdir -p "${HOME}" && chmod 0700 "${HOME}"
if [ ! -w "${HOME}" ]; then echo "${HOME} is not writable"; exit 1; fi

# Prepare custom folder
mkdir -p "${GITEA_CUSTOM}" && chmod 0700 "${GITEA_CUSTOM}"

# Prepare temp folder
mkdir -p "${GITEA_TEMP}" && chmod 0700 "${GITEA_TEMP}"
if [ ! -w "${GITEA_TEMP}" ]; then echo "${GITEA_TEMP} is not writable"; exit 1; fi

#Prepare config file
if [ ! -f "${GITEA_APP_INI}" ]; then
    #Prepare config file folder
    GITEA_APP_INI_DIR=$(dirname "${GITEA_APP_INI}")
    mkdir -p "${GITEA_APP_INI_DIR}" && chmod 0700 "${GITEA_APP_INI_DIR}"
    if [ ! -w "${GITEA_APP_INI_DIR}" ]; then echo "${GITEA_APP_INI_DIR} is not writable"; exit 1; fi

    # Set INSTALL_LOCK to true only if SECRET_KEY is not empty and
    # INSTALL_LOCK is empty
    if [ -n "$SECRET_KEY" ] && [ -z "$INSTALL_LOCK" ]; then
        INSTALL_LOCK=true
    fi

    # Substitute the environment variables in the template
    APP_NAME=${APP_NAME:-"Gitea: Git with a cup of tea"} \
    RUN_MODE=${RUN_MODE:-"prod"} \
    RUN_USER=${USER:-"git"} \
    SSH_DOMAIN=${SSH_DOMAIN:-"localhost"} \
    HTTP_PORT=${HTTP_PORT:-"3000"} \
    ROOT_URL=${ROOT_URL:-""} \
    DISABLE_SSH=${DISABLE_SSH:-"false"} \
    SSH_PORT=${SSH_PORT:-"2222"} \
    SSH_LISTEN_PORT=${SSH_LISTEN_PORT:-} \
    DB_TYPE=${DB_TYPE:-"sqlite3"} \
    DB_HOST=${DB_HOST:-"localhost:3306"} \
    DB_NAME=${DB_NAME:-"gitea"} \
    DB_USER=${DB_USER:-"root"} \
    DB_PASSWD=${DB_PASSWD:-""} \
    INSTALL_LOCK=${INSTALL_LOCK:-"false"} \
    DISABLE_REGISTRATION=${DISABLE_REGISTRATION:-"false"} \
    REQUIRE_SIGNIN_VIEW=${REQUIRE_SIGNIN_VIEW:-"false"} \
    SECRET_KEY=${SECRET_KEY:-""} \
    envsubst < /etc/templates/app.ini > "${GITEA_APP_INI}"
fi

# Replace app.ini settings with env variables in the form GITEA__SECTION_NAME__KEY_NAME
exec /usr/local/bin/gitea config edit-ini --in-place --apply-env "$@"

if [ $# -gt 0 ]; then
    exec "$@"
else
    exec /usr/local/bin/gitea -c "${GITEA_APP_INI}" web
fi
