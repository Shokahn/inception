#!/bin/bash

# Start MariaDB temporarily to set it up
mysqld_safe --skip-networking &
until mysqladmin ping --silent 2>/dev/null; do sleep 1; done

# Create database and users
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# Stop temp instance and restart properly
mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} shutdown
exec mysqld_safe
