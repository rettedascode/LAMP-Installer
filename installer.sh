#!/usr/bin/env bash
set -euo pipefail

###-----------------------------------------------------------------------------
### Defaults (can be overridden by dialog)
###-----------------------------------------------------------------------------

PHP_VERSION="8.2"
PHPMYADMIN_DIR="/usr/share/phpmyadmin"
PHPMYADMIN_ALIAS="/phpmyadmin"
MDB_ROOT_PW=""

###-----------------------------------------------------------------------------
### Helper functions
###-----------------------------------------------------------------------------

abort() {
    echo "ERROR: $*" >&2
    exit 1
}

need_root() {
    if [[ "$EUID" -ne 0 ]]; then
        abort "This script must be run as root (use sudo)."
    fi
}

detect_os() {
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION_ID="${VERSION_ID:-}"
    else
        abort "/etc/os-release not found – supported OS (Debian/Ubuntu) required."
    fi
}

ensure_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo "Installing 'dialog' (TUI dialog utility) ..."
        apt update
        DEBIAN_FRONTEND=noninteractive apt install -y dialog
    fi
}

###-----------------------------------------------------------------------------
### Dialog-based configuration
###-----------------------------------------------------------------------------

choose_php_version() {
    local choice
    choice=$(dialog --clear --stdout \
        --title "PHP Version" \
        --menu "Choose PHP version to install:" 15 60 4 \
        "8.1" "PHP 8.1" \
        "8.2" "PHP 8.2 (recommended)" \
        "8.3" "PHP 8.3 (if available)") || abort "Installation cancelled."

    PHP_VERSION="$choice"
}

get_mariadb_root_password() {
    local pw1 pw2
    while true; do
        pw1=$(dialog --clear --stdout --insecure \
            --passwordbox "Enter new MariaDB root password:" 10 60) \
            || abort "Installation cancelled."

        pw2=$(dialog --clear --stdout --insecure \
            --passwordbox "Repeat MariaDB root password:" 10 60) \
            || abort "Installation cancelled."

        if [[ "$pw1" == "$pw2" ]]; then
            MDB_ROOT_PW="$pw1"
            break
        else
            dialog --clear --msgbox "Passwords do not match. Please try again." 8 50
        fi
    done
}

confirm_start() {
    dialog --clear --yesno \
        "Apache2 + PHP ${PHP_VERSION} + MariaDB + phpMyAdmin will be installed.\n\nMariaDB/MySQL version is taken from your distribution repositories.\n\nDo you want to start the installation now?" \
        12 70

    if [[ $? -ne 0 ]]; then
        abort "Installation cancelled by user."
    fi
}

###-----------------------------------------------------------------------------
### System preparation
###-----------------------------------------------------------------------------

prepare_system() {
    echo "Updating package lists ..."
    apt update

    echo "Upgrading installed packages ..."
    DEBIAN_FRONTEND=noninteractive apt upgrade -y

    echo "Installing basic tools ..."
    apt install -y \
        ca-certificates apt-transport-https lsb-release gnupg curl nano unzip
}

###-----------------------------------------------------------------------------
### Add PHP repository (Sury for Debian, Ondrej PPA for Ubuntu)
###-----------------------------------------------------------------------------

add_php_repo() {
    echo "Setting up PHP repository ..."

    case "$OS_ID" in
        debian)
            echo " -> Debian detected. Adding Sury PHP repository ..."
            curl -fsSL https://packages.sury.org/php/apt.gpg \
                -o /usr/share/keyrings/php-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/php-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
                > /etc/apt/sources.list.d/php.list
            ;;
        ubuntu)
            echo " -> Ubuntu detected. Adding PPA: ondrej/php ..."
            apt install -y software-properties-common
            add-apt-repository -y ppa:ondrej/php
            ;;
        *)
            abort "Unsupported OS: $OS_ID – only Debian/Ubuntu are supported."
            ;;
    esac

    echo "Updating package lists after adding PHP repository ..."
    apt update
}

###-----------------------------------------------------------------------------
### Apache2 + PHP installation
###-----------------------------------------------------------------------------

install_apache_php() {
    echo "Installing Apache2 ..."
    apt install -y apache2

    echo "Installing PHP ${PHP_VERSION} and common extensions ..."
    apt install -y \
        "php${PHP_VERSION}" \
        "php${PHP_VERSION}-cli" \
        "php${PHP_VERSION}-common" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-intl" \
        "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-opcache" \
        "php${PHP_VERSION}-readline" \
        "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-xsl" \
        "php${PHP_VERSION}-zip" \
        "php${PHP_VERSION}-bz2" \
        "libapache2-mod-php${PHP_VERSION}"

    echo "Reloading Apache2 ..."
    systemctl reload apache2
}

###-----------------------------------------------------------------------------
### MariaDB installation & basic hardening
###-----------------------------------------------------------------------------

install_mariadb() {
    echo "Installing MariaDB server and client ..."
    apt install -y mariadb-server mariadb-client

    echo "Applying basic secure settings for MariaDB (similar to mysql_secure_installation) ..."

    # Use socket auth (root user) for initial configuration
    mysql <<SQL
-- Set root password (localhost only)
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MDB_ROOT_PW}';

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Disallow root login from remote hosts
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

FLUSH PRIVILEGES;
SQL

    echo "MariaDB basic hardening done."
    echo "Note: phpMyAdmin root login should work with the password you chose."
}

###-----------------------------------------------------------------------------
### phpMyAdmin installation
###-----------------------------------------------------------------------------

install_phpmyadmin() {
    echo "Downloading and installing phpMyAdmin into ${PHPMYADMIN_DIR} ..."

    cd /usr/share

    if [[ -d phpmyadmin ]]; then
        echo "WARNING: ${PHPMYADMIN_DIR} already exists. Creating a backup."
        mv phpmyadmin "phpmyadmin_backup_$(date +%Y%m%d%H%M%S)"
    fi

    wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip -O phpmyadmin.zip
    unzip phpmyadmin.zip
    rm phpmyadmin.zip

    mv phpMyAdmin-*-all-languages phpmyadmin
    chmod -R 0755 phpmyadmin

    echo "Creating Apache configuration for phpMyAdmin ..."

    cat > /etc/apache2/conf-available/phpmyadmin.conf <<EOF
# phpMyAdmin Apache configuration

Alias ${PHPMYADMIN_ALIAS} ${PHPMYADMIN_DIR}

<Directory ${PHPMYADMIN_DIR}>
    Options SymLinksIfOwnerMatch
    DirectoryIndex index.php
</Directory>

# Disallow web access to directories that don't need it
<Directory ${PHPMYADMIN_DIR}/templates>
    Require all denied
</Directory>
<Directory ${PHPMYADMIN_DIR}/libraries>
    Require all denied
</Directory>
<Directory ${PHPMYADMIN_DIR}/setup/lib>
    Require all denied
</Directory>
EOF

    echo "Enabling phpMyAdmin Apache config and reloading Apache ..."
    a2enconf phpmyadmin
    systemctl reload apache2

    echo "Creating tmp directory for phpMyAdmin and setting permissions ..."
    mkdir -p ${PHPMYADMIN_DIR}/tmp/
    chown -R www-data:www-data ${PHPMYADMIN_DIR}/tmp/
}

###-----------------------------------------------------------------------------
### Final information
###-----------------------------------------------------------------------------

final_info() {
    clear
    cat <<EOF
==============================================================
Installation completed.

Web root:          /var/www/html/
PHP version:       ${PHP_VERSION}
phpMyAdmin URL:    http://<YOUR-SERVER-IP-OR-DOMAIN>${PHPMYADMIN_ALIAS}

MariaDB login in phpMyAdmin:
  - User:     root
  - Password: (the one you entered in the dialog)

IMPORTANT:
- On production systems, consider creating a separate MySQL/MariaDB user
  instead of using 'root' directly from phpMyAdmin.
==============================================================
EOF
}

###-----------------------------------------------------------------------------
### MAIN
###-----------------------------------------------------------------------------

main() {
    need_root
    detect_os

    echo "Detected system:"
    echo "  OS_ID:         ${OS_ID}"
    echo "  OS_VERSION_ID: ${OS_VERSION_ID:-unknown}"
    echo

    ensure_dialog
    choose_php_version
    get_mariadb_root_password
    confirm_start

    prepare_system
    add_php_repo
    install_apache_php
    install_mariadb
    install_phpmyadmin
    final_info
}

main "$@"