#!/bin/bash -u

# This is the only mandidory field
[ -z "$VPS_USER" ] && (echo "VPS_USER not defined" && exit 1)
[ -z "$VPS_GROUP" ] && (echo "VPS_GROUP not defined" && exit 1)
[ -z "$VPS_PASSWORD" ] && [ -z "$VPS_GITHUB_USERS" ] && (echo "Must specify VPS_GITHUB_USERS or VPS_PASSWORD" && exit 1)

PATH="$PATH:/usr/local/bin"

# Create the user if they don't already exist
id "$VPS_USER"
if [ $? -ne 0 ]; then
  adduser --disabled-password --gecos "" "$VPS_USER"
  adduser "$VPS_USER" "$VPS_GROUP"
fi

VPS_HOME=$(getent passwd "$VPS_USER" | cut -d: -f6)

if [ -n "${DB_USER:-}" ]; then
cat<< __EOF__ >"$VPS_HOME/.my.cnf"
[client]
user=${DB_USER:-}
password=${DB_PASS:-}
database=${DB_NAME:-}
host=${DB_HOST:-}
__EOF__

[ -d /etc/env.d ] || mkdir -p /etc/env.d
cat<< __EOF__ > "/etc/env.d/db.sh"
export DB_USER=${DB_USER:-}
export DB_PASS=${DB_PASS:-}
export DB_NAME=${DB_NAME:-}
export DB_HOST=${DB_HOST:-}
__EOF__
fi

chown "$VPS_USER:$VPS_GROUP" -R "$VPS_HOME"
chmod 755 "$VPS_HOME"

# Set the password for the user if one provided
if [ ! -z "$VPS_PASSWORD" ]; then
  echo "$VPS_USER:$VPS_PASSWORD" | chpasswd
  # Enable password-based logins
  sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  unset VPS_PASSWORD
fi

if [ "$VPS_ENABLE_SUDO" = "true" ]; then 
  sudo usermod -aG sudo "$VPS_USER"
  unset VPS_ENABLE_SUDO
fi

if [ ! -z "$VPS_GITHUB_USERS" ]; then
  import-github-ssh-keys.sh "$VPS_GITHUB_USERS" "$VPS_USER"
  unset VPS_GITHUB_USERS
fi