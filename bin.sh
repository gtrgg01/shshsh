#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Update and upgrade the system
apt update && apt upgrade -y

# Install Nginx and Apache
apt install nginx apache2 -y

# Start and enable Nginx and Apache
systemctl start nginx
systemctl enable nginx
systemctl start apache2
systemctl enable apache2

# Install Certbot (Let's Encrypt client) and the Apache plugin
apt install certbot python3-certbot-apache -y

# Prompt the user to enter the domain
echo "Enter your domain (e.g., example.com):"
read domain

# Obtain SSL certificates for the domain
certbot --apache -d $domain

# Optional: Configure Nginx as a reverse proxy (example config)
echo "Do you want to configure Nginx as a reverse proxy for $domain? (y/n)"
read configure_nginx

if [ "$configure_nginx" == "y" ]; then
    cat > /etc/nginx/sites-available/$domain <<EOF
server {
    listen 80;
    server_name $domain www.$domain;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
EOF

    ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    systemctl restart nginx
fi

echo "Installation and configuration complete for $domain."
