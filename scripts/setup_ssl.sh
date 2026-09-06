#!/bin/bash
set -e

DOMAIN="engine.getgigaride.com"
EMAIL="info@getgigaride.com"
VPS_IP="69.62.127.50"

echo "============================================="
echo " 🔒 Giga Ride Let's Encrypt SSL Provisioner"
echo " Target Domain: $DOMAIN"
echo "============================================="

# 1. Verify DNS Resolution
echo "[1/3] Checking DNS resolution for $DOMAIN..."
RESOLVED_IP=$(dig +short "$DOMAIN" | tail -n1)

if [ "$RESOLVED_IP" != "$VPS_IP" ]; then
    echo "⚠️  DNS Warning: $DOMAIN resolved to '$RESOLVED_IP', expected '$VPS_IP'."
    echo "Please ensure the A record for 'engine' points to '$VPS_IP' in your domain DNS manager."
    echo "Attempting certificate challenge anyway (in case of local caching)..."
fi

# 2. Issue Certificate via Certbot
echo "[2/3] Requesting SSL Certificate from Let's Encrypt..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect --keep-until-expiring

# 3. Reload Nginx
echo "[3/3] Testing and reloading Nginx..."
nginx -t
systemctl reload nginx

echo "============================================="
echo " ✅ SSL Provisioning Completed for https://$DOMAIN"
echo "============================================="
