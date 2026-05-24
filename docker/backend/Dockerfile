# ========================================
# STAGE 1: Base - Common PHP setup
# ========================================
FROM php:8.2-apache AS base

WORKDIR /var/www/html

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libgmp-dev \
    curl \
    tzdata \
    # Clean up to reduce image size
    && ln -snf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime \
    && echo Asia/Ho_Chi_Minh > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install \
        pdo_mysql \
        mysqli \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip

# Configure Apache
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && a2enmod rewrite headers

# ========================================
# STAGE 2: Development - With debugging tools
# ========================================
FROM base AS development

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    nano \
    && rm -rf /var/lib/apt/lists/* 

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy development PHP configuration
COPY ./docker/backend/dev.ini /usr/local/etc/php/conf.d/dev.ini

EXPOSE 80

# ========================================
# STAGE 3: Production - Optimized and secure
# ========================================
FROM base AS production

# Install OPcache for performance
RUN docker-php-ext-install opcache && \
    docker-php-ext-enable opcache

# Copy production PHP configuration
COPY ./docker/backend/prod.ini /usr/local/etc/php/conf.d/prod.ini

# Install Composer temporarily for dependency installation
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application code
COPY --chown=www-data:www-data . .

# Install dependencies and optimize for production
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-scripts \
    --no-interaction \
    # Remove Composer after use
    && rm /usr/bin/composer \
    && find /var/www/html -type d -exec chmod 755 {} + \
    && find /var/www/html -type f -exec chmod 644 {} +

# Security: Configure Apache to hide server info
RUN echo 'ServerTokens Prod' >> /etc/apache2/apache2.conf && \
    echo 'ServerSignature Off' >> /etc/apache2/apache2.conf

EXPOSE 80