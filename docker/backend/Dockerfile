FROM composer:2.10.3@sha256:2cf275428757e5435a667bfc0d038b14520ca02be2b1b70d44a05c8c19e2de48 AS composer

FROM php:8.2.35-apache-trixie@sha256:7b7574ed556f3cd450aafbdcb1424acdfbd67d540ce50c2c9f03e5698bca93d0 AS base
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev libonig-dev libxml2-dev libzip-dev curl supervisor tzdata \
    libbrotli1 \
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libbrotli1)" ge '1.1.0-2+deb13u1' \
    && ln -snf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime \
    && echo Asia/Ho_Chi_Minh > /etc/timezone \
    && docker-php-ext-install pdo_mysql mysqli mbstring exif pcntl bcmath gd zip opcache \
    && rm -rf /var/lib/apt/lists/*
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && a2enmod rewrite headers
COPY ./docker/backend/security.ini /usr/local/etc/php/conf.d/zz-security.ini
RUN apt-mark manual libpng16-16t64 libonig5 libxml2 libzip5 libbrotli1 \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
        libpng-dev libonig-dev libxml2-dev libzip-dev linux-libc-dev $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*

FROM base AS vendor
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY ./src/backend/composer.json ./src/backend/composer.lock ./
RUN composer install --no-dev --prefer-dist --no-scripts --no-interaction
COPY ./src/backend .
RUN mkdir -p bootstrap/cache storage/framework/cache storage/framework/sessions storage/framework/views storage/logs \
    && composer dump-autoload --optimize --no-dev \
    && composer check-platform-reqs --no-dev

FROM base AS development
RUN apt-get update && apt-get install -y --no-install-recommends nano \
    && rm -rf /var/lib/apt/lists/*
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY ./docker/backend/dev.ini /usr/local/etc/php/conf.d/dev.ini
EXPOSE 80

FROM vendor AS test
RUN composer install --prefer-dist --no-interaction && touch .env.testing
COPY ./src/backend/tests ./tests
ENV APP_ENV=testing CACHE_STORE=array SESSION_DRIVER=array QUEUE_CONNECTION=sync
CMD ["php", "artisan", "test"]

FROM base AS production
COPY ./docker/backend/prod.ini /usr/local/etc/php/conf.d/prod.ini
COPY ./docker/backend/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --from=vendor /var/www/html .
RUN mkdir -p bootstrap/cache storage/framework/cache storage/framework/sessions storage/framework/views storage/logs \
    && chown -R root:root /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} + \
    && find /var/www/html -type f -exec chmod 644 {} + \
    && chown -R www-data:www-data storage bootstrap/cache \
    && echo 'ServerTokens Prod' >> /etc/apache2/apache2.conf \
    && echo 'ServerSignature Off' >> /etc/apache2/apache2.conf
EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
