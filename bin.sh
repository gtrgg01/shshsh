#!/bin/bash

# Ask for the number of websites
echo "Are you setting up one website or multiple websites? (Enter '1' for one or '2' for multiple)"
read choice

if [ "$choice" -eq 1 ]; then
    echo "Enter the domain name for your website:"
    read domain
    domains=("$domain")
elif [ "$choice" -eq 2 ]; then
    echo "Enter the number of websites you want to set up:"
    read num_sites
    domains=()
    for (( i=1; i<=num_sites; i++ ))
    do
        echo "Enter the domain name for website $i:"
        read domain
        domains+=("$domain")
    done
else
    echo "Invalid choice. Please run the script again and choose either '1' or '2'."
    exit 1
fi

# Update and install Apache and required packages
apt update && apt install -y \
    curl php-curl vim unzip fail2ban php apache2 libapache2-mod-php php-apcu php-bcmath php-mbstring php-soap php-mysql \
    php-curl mcrypt php-zip certbot curl php-gd php-parser php-imagick php-phpseclib php-common php-mysql php-gd \
    php-imap php-json php-curl php-zip php-xml php-mbstring php-bz2 php-intl php-gmp php-sqlite3 vim

# Create and configure remoteip.conf for Apache
cat <<EOT > /etc/apache2/conf-available/remoteip.conf
RemoteIPHeader X-Forwarded-For
RemoteIPTrustedProxy 127.0.0.1
EOT

# Enable necessary Apache modules and configuration
a2enmod remoteip rewrite
a2enconf remoteip

# Modify apache2.conf to update directory settings
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Update Apache's default site configuration
sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/site|' /etc/apache2/sites-enabled/000-default.conf

# Create the directory for the primary domain
mkdir -p /var/www/site

# Update Apache to listen on localhost
sed -i 's|Listen 80|Listen 127.0.0.1:80|' /etc/apache2/ports.conf

# Stop Apache to avoid conflicts with Nginx
service apache2 stop

# Install Nginx and additional packages
apt install -y nginx php-fpm curl python3-certbot-nginx certbot fail2ban torsocks php-mysql unzip vim php-zip \
    php-apcu php-bcmath php-mbstring php-soap php-mysql php-curl mcrypt php-zip certbot curl php-gd

# Update Nginx default site configuration
sed -i 's|listen 80 default_server;|listen YOURSERVERIP:80 default_server;|' /etc/nginx/sites-enabled/default
sed -i '/listen \[::\]:80 default_server;/d' /etc/nginx/sites-enabled/default

# Restart Nginx and Apache services
service nginx restart
service apache2 restart

# Loop through each domain to create SSL certificates and setup directories
for i in "${!domains[@]}"; do
    domain=${domains[$i]}
    certbot --nginx --email info@"$domain" --rsa-key-size 4096 --agree-tos --no-eff-email --redirect -d "$domain"
    
    # Update Nginx configuration to proxy to Apache
    sed -i "/server_name $domain;/a \
location / {\
proxy_pass http://127.0.0.1;\
proxy_redirect off;\
proxy_buffering on;\
proxy_buffers 50 1m;\
proxy_buffer_size 2m;\
proxy_read_timeout 120;\
proxy_ignore_client_abort off;\
proxy_max_temp_file_size 0;\
proxy_set_header Host \$host;\
proxy_set_header X-Real-IP \$remote_addr;\
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\
} \
listen 443 ssl proxy_protocol; \
set_real_ip_from 0.0.0.0/0; \
real_ip_header proxy_protocol; \
real_ip_recursive on;" /etc/nginx/sites-enabled/default
    
    # Create directory for the website
    mkdir -p /var/www/site$i

    # Update Apache configuration for the new domain
    cat <<EOT >> /etc/apache2/sites-enabled/000-default.conf

<VirtualHost *:80>
    ServerName $domain
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/site$i
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOT

done

# Restart services
service apache2 restart
service nginx restart

echo "Setup complete for ${#domains[@]} website(s)!"
