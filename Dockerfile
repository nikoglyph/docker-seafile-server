ARG DOCKER_BASE_IMAGE=debian:stretch-slim
FROM ${DOCKER_BASE_IMAGE}

MAINTAINER André Stein

EXPOSE 80
EXPOSE 443

VOLUME /data

ARG SEAFILE_VERSION=6.2.2
ENV SEAFILE_VERSION ${SEAFILE_VERSION}

# Download location. Options currently:
# <https://download.seadrive.org> | <https://github.com/haiwen/seafile-rpi/releases/download/v${SEAFILE_VERSION}>
ARG SEAFILE_DOWNLOAD_URL=https://download.seadrive.org
# CPU architecture qualifier part of filename of seafile binaries.
# Please note that armhf i.e. 'stable_pi' is only available from haiwen's github repo. Current options:
# <x86-64> | <i386> | <stable_pi>
ARG SEAFILE_ARCH_QUALIFIER=x86-64

# Install seafile dependencies and make sure to clean
# all apt caches, locales, man pages and docs
RUN apt-get update && apt-get -y install \
	libpython2.7 \
	nginx \
	procps \
	python2.7 \
	python-imaging \
	python-ldap \
	python-requests \
	python-setuptools \
	python-urllib3 \
	sqlite3 \
	wget && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/locale/* && \
    rm -rf /usr/share/man/* && \
    rm -rf /usr/share/doc/*

# download and extract seafile release
RUN mkdir seafile && \
    cd /seafile && \
	wget -O - ${SEAFILE_DOWNLOAD_URL}/seafile-server_${SEAFILE_VERSION}_${SEAFILE_ARCH_QUALIFIER}.tar.gz | tar xzf -

# run initial seafile setup script with initial placeholder
# values which will be patched in the container start script
RUN cd /seafile/seafile-server-* && ./setup-seafile.sh auto \
	-n "xxxseafilexxx" \
	-i 000.000.000.000

COPY start-seafile.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-seafile.sh

# patch seahub's check_init_admin.py script which tries to
# interactively set admin's mail and password. We directly
# patch it to use environment variables
RUN sed -i 's/= ask_admin_email()/= os\.environ\["SEAFILE_ADMIN_MAIL"\]/' /seafile/seafile-server-latest/check_init_admin.py
RUN sed -i 's/= ask_admin_password()/= os\.environ\["SEAFILE_ADMIN_PASSWORD"\]/' /seafile/seafile-server-latest/check_init_admin.py

# patch seafile's update scripts to be non-interactive
RUN sed -i 's@read dummy@@g' /seafile/seafile-server-latest/upgrade/upgrade_*sh

# setup nginx configuration files
RUN rm /etc/nginx/sites-*/*
COPY nginx/seafile-*.conf /etc/nginx/sites-available/
COPY nginx/snippets/* /etc/nginx/snippets/

CMD /usr/local/bin/start-seafile.sh
