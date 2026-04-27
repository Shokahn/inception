#!/bin/bash

# Fix php-fpm to listen on TCP 9000 (not a unix socket) — must run every start
sed -i 's|listen = /run/php/php7.4-fpm.sock|listen = 9000|' \
    /etc/php/7.4/fpm/pool.d/www.conf

# Wait for MariaDB to be ready
echo "Waiting for MariaDB..."
while ! mysqladmin ping -h mariadb -u root -p${MYSQL_ROOT_PASSWORD} --silent 2>/dev/null; do
    sleep 1
done
echo "MariaDB is ready."

WP_PATH=/var/www/html

# Download and install WordPress only on first run
if [ ! -f "$WP_PATH/wp-login.php" ]; then
    wp core download --path=$WP_PATH --allow-root

    wp config create \
        --path=$WP_PATH \
        --dbname=$MYSQL_DATABASE \
        --dbuser=$MYSQL_USER \
        --dbpass=$MYSQL_PASSWORD \
        --dbhost=mariadb \
        --allow-root

    wp core install \
        --path=$WP_PATH \
        --url=https://$DOMAIN_NAME \
        --title=$WP_TITLE \
        --admin_user=$WP_ADMIN \
        --admin_password=$WP_ADMIN_PASSWORD \
        --admin_email=$WP_ADMIN_EMAIL \
        --allow-root

    wp user create $WP_USER $WP_USER_EMAIL \
        --role=author \
        --user_pass=$WP_USER_PASSWORD \
        --path=$WP_PATH \
        --allow-root
fi

exec php-fpm7.4 -F
