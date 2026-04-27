#!/bin/bash

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

SENTINEL=/var/lib/mysql/.inception_initialized

if [ ! -f "$SENTINEL" ]; then
    if [ ! -d /var/lib/mysql/mysql ]; then
        echo "[mariadb-init] Initializing data directory..."
        mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db
        echo "[mariadb-init] Data directory initialized."
    fi

    echo "[mariadb-init] Starting temporary MariaDB instance..."
    mysqld_safe --skip-networking &
    until mysqladmin ping --silent 2>/dev/null; do sleep 1; done
    echo "[mariadb-init] MariaDB is up, running setup SQL..."

    mysql -u root -e "
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
"
    touch "$SENTINEL"
    echo "[mariadb-init] Setup SQL done, shutting down temp instance..."
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait
    echo "[mariadb-init] Init complete."
fi

echo "[mariadb-init] Starting MariaDB..."
exec mysqld_safe
