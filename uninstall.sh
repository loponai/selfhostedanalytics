#!/bin/bash
set -e

# Self-Hosted Analytics Uninstaller

DATA_DIR="/opt/umami"
INSTALL_DIR="/opt/selfhostedanalytics"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        Self-Hosted Analytics Uninstaller             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (sudo)"
    exit 1
fi

echo "This will remove:"
echo "  - Umami containers and images"
echo "  - Nginx/Caddy config for analytics"
echo "  - Data directory ($DATA_DIR)"
echo "  - Installer directory ($INSTALL_DIR)"
echo ""
echo "⚠  Your database will be PERMANENTLY DELETED."
echo ""
read -p "Are you sure? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Stop and remove containers
echo ""
echo "→ Stopping containers..."
if [ -f "$DATA_DIR/docker-compose.yml" ]; then
    cd "$DATA_DIR"
    docker compose down -v 2>/dev/null || true
fi

# Remove nginx config
echo "→ Removing reverse proxy config..."
if [ -f /etc/nginx/sites-enabled/umami ]; then
    rm -f /etc/nginx/sites-enabled/umami
    rm -f /etc/nginx/sites-available/umami
    nginx -t && systemctl reload nginx 2>/dev/null || true
fi

# Remove caddy config (restore default)
if command -v caddy &>/dev/null && [ -f /etc/caddy/Caddyfile ]; then
    if grep -q "localhost:3000" /etc/caddy/Caddyfile 2>/dev/null; then
        echo "" > /etc/caddy/Caddyfile
        systemctl restart caddy 2>/dev/null || true
    fi
fi

# Remove data
echo "→ Removing data..."
rm -rf "$DATA_DIR"

# Remove installer
echo "→ Removing installer..."
rm -rf "$INSTALL_DIR"

echo ""
echo "✓ Uninstall complete."
echo ""
echo "Note: Docker itself was NOT removed."
echo "To remove Docker: apt remove docker-ce docker-ce-cli containerd.io"
echo ""
