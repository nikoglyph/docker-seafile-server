#!/bin/bash

set -u
set -e
set -o pipefail

# infer SEAFILE_MAJOR from SEAFILE_VERSION
read major minor revision <<< $( echo ${SEAFILE_VERSION} | awk -F"." '{print $1" "$2" "$3}' )
SEAFILE_MAJOR=${major}.${minor:-0}

# copy initial seahub data folder if not existant
# and copy initial seafile data sqlite database if not existant
if [[ ! -f /data/seahub.db ]] && [[ ! -f /data/seahub-data ]]; then
    echo "Nothing found in /data folder. Copying initial data files..."
    cp /seafile/seahub.db /data/
    cp -rv /seafile/seahub-data /data
    cp -rv /seafile/seafile-data /data
    cp -rv /seafile/ccnet /data

    # initialize seafile major version in /data folder
    echo -n ${SEAFILE_MAJOR} > /data/seafile_version
fi

# remove initial seafile data files and replace
# them my symlinks to /data folder
rm -rf /seafile/seahub-data /seafile/seafile-data /seafile/seahub.db /seafile/ccnet
ln -s /data/seahub-data /seafile
ln -s /data/seahub.db /seafile
ln -s /data/seafile-data /seafile
ln -s /data/ccnet /seafile

echo "Adapting configuration of seafile service:"
echo " - hostname: ${SEAFILE_HOSTNAME}"
echo " - server name: ${SEAFILE_SERVER_NAME}"
echo " - external port: ${SEAFILE_EXTERNAL_PORT}"

# adapt configuration files to configuration
# passed by environment variables
sed -i "s@xxxseafilexxx@${SEAFILE_SERVER_NAME}@g" /seafile/conf/*

current_major=$(cat /data/seafile_version)
echo "Current seafile data major version: $current_major"

# upgrade version if necessary. that means seafile
# major stored in /data folder doesn't match this one's
if [[ "$current_major" != "${SEAFILE_MAJOR}" ]]; then
    if [[ "$current_major" > "${SEAFILE_MAJOR}" ]]; then
      echo "Error: trying to run a newer version ($current_major) on an old seafile version (${SEAFILE_MAJOR})!"
      exit 1
    fi

    echo "#"
    echo "# Upgrading seafile /data folder from $current_major to $SEAFILE_MAJOR..."
    echo "#"

    cd /seafile/seafile-server-latest/upgrade
    for upgrade_script in $(ls -1 | grep "upgrade_.*sh" | grep -A 100000 "upgrade_$current_major" | sort -h); do
      echo " - Executing '$upgrade_script'..."
      ./$upgrade_script
    done

    echo -n ${SEAFILE_MAJOR} > /data/seafile_version

    echo "#"
    echo "# Upgrade done."
    echo "#"
fi

# Setup nginx
sed -i "s@%hostname%@${SEAFILE_HOSTNAME}@g" /etc/nginx/sites-available/*.conf /etc/nginx/snippets/*
sed -i "s@%cert_file%@${SSL_CERT_FILE:-/etc/ssl/cert.pem}@g" /etc/nginx/sites-available/seafile-https.conf
sed -i "s@%privkey_file%@${SSL_PRIVKEY_FILE:-/etc/ssl/privkey.pem}@g" /etc/nginx/sites-available/seafile-https.conf
sed -i "s@%dhparam_file%@${SSL_DHPARAM_FILE:-/etc/ssl/dhparam.pem}@g" /etc/nginx/sites-available/seafile-https.conf

# cleanup old server configuration
rm -f /etc/nginx/sites-enabled/*

protocol=""
if [[ "${USE_SSL:-off}" == "off" ]]; then
    ln -s /etc/nginx/sites-available/seafile-http.conf /etc/nginx/sites-enabled/
    protocol="http"
else
  echo "Enabling SSL (mode: $USE_SSL)..."
  ln -s /etc/nginx/sites-available/seafile-https.conf /etc/nginx/sites-enabled/
  protocol="https"
fi

# patch seafile and seahub configuration for nginx
sed -i "s@SERVICE\_URL.*@SERVICE\_URL = $protocol\:\/\/${SEAFILE_HOSTNAME}\:${SEAFILE_EXTERNAL_PORT}@g" /seafile/conf/ccnet.conf
echo "FILE_SERVER_ROOT = '$protocol://${SEAFILE_HOSTNAME}:${SEAFILE_EXTERNAL_PORT}/seafhttp'" >> /seafile/conf/seahub_settings.py

# enable two-factor authentication
echo "ENABLE_TWO_FACTOR_AUTH = True" >> /seafile/conf/seahub_settings.py

#
# start the services
#

cd /seafile/seafile-server-latest

echo "Starting seafile.." && ./seafile.sh start
echo "Starting seahub..." && ./seahub.sh start

service nginx start || (tail /var/log/nginx/error.log; exit 1;)

# Output log files that also keeps container running
tail -f /var/log/nginx/error.log /var/log/nginx/seahub.error.log /seafile/logs/*.log

