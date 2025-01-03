#!/bin/bash

# Source variables file
if [ -f "variables.sh" ]; then
    source variables.sh
else
    echo "Le fichier variables.sh est manquant. Veuillez le créer avec les variables requises."
    exit 1
fi

# Fonction pour détecter la distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        echo "Impossible de détecter la distribution"
        exit 1
    fi
}

# Installation des dépendances selon la distribution
install_dependencies() {
    case $OS in
        "Debian GNU/Linux"|"Ubuntu")
            apt update
            apt install -y apache2 mariadb-server libapache2-mod-php php php-gd php-curl \
                         php-zip php-dom php-xml php-mbstring php-mysql php-intl \
                         php-imagick php-bcmath php-gmp unzip curl
            ;;
        "Fedora")
            dnf update -y
            dnf install -y httpd mariadb-server php php-gd php-curl php-zip php-dom \
                         php-xml php-mbstring php-mysql php-intl php-imagick \
                         php-bcmath php-gmp unzip curl
            systemctl enable httpd
            systemctl start httpd
            ;;
        "Raspbian GNU/Linux")
            apt update
            apt install -y apache2 mariadb-server libapache2-mod-php php php-gd php-curl \
                         php-zip php-dom php-xml php-mbstring php-mysql php-intl \
                         php-imagick php-bcmath php-gmp unzip curl
            ;;
        *)
            echo "Distribution non supportée"
            exit 1
            ;;
    esac
}

# Configuration de la base de données
configure_database() {
    systemctl start mariadb
    systemctl enable mariadb

    mysql -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    mysql -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
}

# Installation de Nextcloud
install_nextcloud() {
    # Téléchargement de Nextcloud
    curl -O https://download.nextcloud.com/server/releases/latest.zip
    
    # Nettoyage du répertoire web
    rm -rf /var/www/html/*
    
    # Extraction de Nextcloud
    unzip latest.zip -d /var/www/
    mv /var/www/nextcloud/* /var/www/html/
    rm -r /var/www/nextcloud
    rm latest.zip
    
    # Configuration des permissions
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
}

# Configuration du vhost Apache
configure_vhost() {
    cat > /etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud-error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud-access.log combined
</VirtualHost>
EOF

    a2ensite nextcloud.conf
    a2enmod rewrite headers env dir mime
    systemctl restart apache2
}

# Exécution principale
echo "Début de l'installation de Nextcloud..."

detect_distribution
install_dependencies
configure_database
install_nextcloud
configure_vhost

echo "Installation et configuration terminées!"
echo "Vous pouvez maintenant accéder à Nextcloud via http://$DOMAIN_NAME"
echo "Veuillez compléter l'installation via l'interface web avec les informations suivantes:"
echo "Base de données: nextcloud"
echo "Utilisateur DB: nextcloud"
echo "Mot de passe DB: $DB_PASSWORD"
