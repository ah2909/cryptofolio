# ========================================
# STAGE 1: Composer dependencies
# ========================================
FROM composer:2 AS vendor

WORKDIR /app

# Copy composer files first for Docker layer caching
COPY ./src/backend/composer.json ./src/backend/composer.lock ./

# Install PHP dependencies
RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts \
    --no-interaction

# Copy application source
COPY ./src/backend .

# Generate optimized autoload
RUN composer dump-autoload \
    --optimize \
    --no-dev


# ========================================
# STAGE 2: Base PHP image
# ========================================
FROM php:8.2-apache AS base

WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    curl \
    supervisor \
    tzdata \
    && ln -snf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime \
    && echo Asia/Ho_Chi_Minh > /etc/timezone \
    && docker-php-ext-install \
        pdo_mysql \
        mysqli \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Configure Apache
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri \
        -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/sites-available/*.conf \
    && a2enmod rewrite headers


# ========================================
# STAGE 3: Development
# ========================================
FROM base AS development

RUN apt-get update && apt-get install -y \
    nano \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY ./docker/backend/dev.ini \
    /usr/local/etc/php/conf.d/dev.ini

EXPOSE 80

# ========================================
# STAGE 4: Production
# ========================================
FROM base AS production

# Install OPcache
RUN docker-php-ext-install opcache \
    && docker-php-ext-enable opcache

# PHP production config
COPY ./docker/backend/prod.ini \
    /usr/local/etc/php/conf.d/prod.ini

# Supervisor config
COPY ./docker/backend/supervisord.conf \
    /etc/supervisor/conf.d/supervisord.conf

# Copy application code
COPY --chown=www-data:www-data ./src/backend .

# Copy vendor directory from composer stage
COPY --from=vendor \
    --chown=www-data:www-data \
    /app/vendor \
    ./vendor

# Copy generated autoload files
COPY --from=vendor \
    --chown=www-data:www-data \
    /app/composer.lock \
    ./

# Optimize permissions
RUN find /var/www/html -type d -exec chmod 755 {} + \
    && find /var/www/html -type f -exec chmod 644 {} +

# Hide Apache version information
RUN echo 'ServerTokens Prod' >> /etc/apache2/apache2.conf \
    && echo 'ServerSignature Off' >> /etc/apache2/apache2.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]