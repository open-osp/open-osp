#!/bin/bash
# Path to the HAProxy configuration file
HAPROXY_CFG="haproxy.cfg"

# Backup the existing haproxy.cfg
BACKUP_CFG="haproxy.cfg.bak"
echo "Backing up current HAProxy config to $BACKUP_CFG"
cp $HAPROXY_CFG $BACKUP_CFG

# Add the config to block PUT requests globally in the frontend section
echo "Updating $HAPROXY_CFG to block PUT requests"

# Find the frontend section and insert the PUT block rule before any default_backend
sed -i '/frontend/,/use_backend/ {
    /maxconn/ a \	\n \tacl is_put_method method PUT
    /maxconn/ a \	http-request deny if is_put_method
}' $HAPROXY_CFG
echo "Added PUT request blocking configuration."

# Restart HAProxy to apply the changes
echo "Restarting HAProxy service to apply the changes..."
sudo systemctl restart haproxy

# Check if HAProxy started successfully
if systemctl is-active --quiet haproxy; then
    echo "HAProxy restarted successfully!"
else
    echo "Error: HAProxy failed to restart."
fi
