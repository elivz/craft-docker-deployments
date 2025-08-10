# Set PHP and Node Versions
ARG PHP_VERSION=8.4
ARG NODE_VERSION=jod

# Base image
FROM serversideup/php:${PHP_VERSION}-fpm-nginx AS base

# PHP memory/execution settings
ENV PHP_MEMORY_LIMIT="1024M"
ENV PHP_UPLOAD_MAX_FILE_SIZE="100M"
ENV PHP_POST_MAX_SIZE="100M"
ENV PHP_MAX_INPUT_VARS=5000

# PHP opcache settings
ENV PHP_OPCACHE_ENABLE=1
ENV PHP_OPCACHE_INTERNED_STRINGS_BUFFER=16
ENV PHP_OPCACHE_REVALIDATE_FREQ=0
ENV PHP_OPCACHE_MEMORY_CONSUMPTION=256

# Custom from ini
ENV PHP_OPCACHE_MAX_WASTED_PERCENTAGE=10
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=1
ENV PHP_OPCACHE_JIT="tracing"
ENV PHP_OPCACHE_JIT_BUFFER_SIZE=100M

# Install necessary server packages and PHP extensions
USER root
RUN docker-php-serversideup-dep-install-debian "nano default-mysql-client"
RUN install-php-extensions gd bcmath soap intl imagick
USER www-data

# Custom PHP configuration file
COPY --chmod=755 ./infra/web/etc/php/zzz-custom-php.ini /usr/local/etc/php/conf.d/


# For all non-dev environments, build our front-end assets
FROM node:${NODE_VERSION} AS fed
WORKDIR /app
RUN mkdir -p public
COPY package.json package-lock.json vite.config.js ./
COPY ./src ./src
COPY ./templates ./templates
RUN npm --loglevel=error ci --no-progress
RUN npm run build


# For all non-dev environments, install our Composer dependencies
FROM base AS vendor
#COPY ./modules ./modules
COPY composer.json composer.lock ./
RUN composer install --no-interaction --prefer-dist --no-ansi --no-scripts --no-progress --no-dev --optimize-autoloader -d /var/www/html/


# Our app stage serves as the foundation for our deploy environments
# and will copy in front-end assets and Composer dependencies, then copy
# the rest of our project in, and run as www-data
FROM base AS app
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
COPY --chown=www-data:www-data ./config ./config
COPY --chown=www-data:www-data ./migrations ./migrations
COPY --chown=www-data:www-data ./modules ./modules
COPY --chown=www-data:www-data ./public ./public
COPY --chown=www-data:www-data ./templates ./templates
COPY --chown=www-data:www-data ./bootstrap.php ./bootstrap.php
COPY --chown=www-data:www-data ./craft ./craft
COPY --from=fed --chown=www-data:www-data /app/public/assets/ ./public/assets/
COPY --from=vendor --chown=www-data:www-data /var/www/html/vendor/ ./vendor/
RUN mkdir -p ./storage && chown -R www-data:www-data ./storage
