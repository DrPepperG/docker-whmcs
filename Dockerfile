ARG ALPINE_VERSION=3.16
FROM alpine:${ALPINE_VERSION}

RUN mkdir /var/www/whmcs -p

# Setup document root
WORKDIR /var/www/whmcs

# Install packages and remove default server definition
RUN apk add --no-cache \
  curl \
  nginx \
  tar \
  gzip \
  php81 \
  php81-fpm \
  php81-mysqli \
  php81-common \
  php81-redis \
  php81-bcmath \
  php81-enchant \
  php81-gd \
  php81-intl \
  php81-json \
  php81-xml \
  php81-pear \
  php81-zip \
  php81-bz2 \
  php81-mbstring \
  php81-curl \
  php81-pdo_mysql \
  dcron \
  libcap \
  supervisor

# Crontab enabler
RUN chown nobody:nobody /usr/sbin/crond \
    && setcap cap_setgid=ep /usr/sbin/crond

# Copy Entrypoint
COPY ./entrypoint.sh /var
RUN chmod +x /var/entrypoint.sh

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php81/php-fpm.conf
COPY config/php.ini /etc/php81/conf.d/custom.ini
RUN mkdir /var/lib/php81/sessions

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install ioncube loader
RUN curl -o /tmp/ioncube.tar.gz https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz && \
  tar -xvf /tmp/ioncube.tar.gz -C /tmp/ && \
  mkdir -p /usr/lib/php/ioncube && \
  cp /tmp/ioncube/ioncube_loader_lin_8.1.so /usr/lib/php/ioncube/. && \
  echo 'zend_extension = /usr/lib/php/ioncube/ioncube_loader_lin_8.1.so' > /etc/php81/php.ini && \
  rm -r /tmp/*

# Install crontabs
RUN echo "* * * * * /usr/bin/php81 -q /var/www/whmcs/crons/cron.php" >> /var/spool/cron/crontabs/nobody && touch /var/log/crond

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody:nobody /var/www/whmcs /run /var/lib/nginx /var/log/nginx /var/lib/php81 /var/lib/php81/sessions /var/log/crond

# Switch to use a non-root user from here on
USER nobody

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
ENTRYPOINT ["/var/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
