#!/bin/bash
set -e

# Self-Hosted Analytics Setup
# Installs Umami analytics with PostgreSQL, Nginx/Caddy, and SSL

INSTALL_DIR="/opt/selfhostedanalytics"
DATA_DIR="/opt/umami"

# ──────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────

info()    { echo -e "\033[1;34m→\033[0m $1"; }
success() { echo -e "\033[1;32m✓\033[0m $1"; }
warn()    { echo -e "\033[1;33m!\033[0m $1"; }
error()   { echo -e "\033[1;31m✗\033[0m $1"; exit 1; }

validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        return 1
    fi
    if [[ "$domain" =~ \.\. ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

template() {
    local src="$1" dst="$2"
    cp "$src" "$dst"
    sed -i "s|__DOMAIN__|${DOMAIN}|g" "$dst"
}

nginx_config_path() {
    if [ "$OS_FAMILY" = "rhel" ]; then
        echo "/etc/nginx/conf.d/umami.conf"
    else
        echo "/etc/nginx/sites-available/umami"
    fi
}

generate_secret() {
    openssl rand -hex "$1" 2>/dev/null || head -c "$1" /dev/urandom | xxd -p | tr -d '\n'
}

# ──────────────────────────────────────────────
# OS detection
# ──────────────────────────────────────────────

if [ -f /etc/debian_version ]; then
    OS_FAMILY="debian"
    pkg_install() { apt-get install -y -qq "$@"; }
    pkg_update()  { apt-get update -qq; }
elif [ -f /etc/redhat-release ]; then
    OS_FAMILY="rhel"
    pkg_install() { yum install -y -q "$@"; }
    pkg_update()  { true; }
else
    OS_FAMILY="unknown"
    pkg_install() { echo "Please install manually: $@"; }
    pkg_update()  { true; }
fi

# ──────────────────────────────────────────────
# Check root
# ──────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    error "Please run as root (sudo)"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║           Umami Analytics Setup                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────
# Step 1: Collect information
# ──────────────────────────────────────────────

info "Step 1/7: Configuration"
echo ""

read -p "  Enter your analytics domain (e.g. analytics.yourdomain.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    error "Domain is required"
fi
if ! validate_domain "$DOMAIN"; then
    error "Invalid domain format. Use only letters, numbers, dots, and hyphens (e.g. analytics.yourdomain.com)"
fi

read -p "  Enter your email (for SSL certificates): " EMAIL
if [ -z "$EMAIL" ]; then
    error "Email is required"
fi
if ! validate_email "$EMAIL"; then
    error "Invalid email format"
fi

echo ""
echo "  Choose your reverse proxy:"
echo "    1) Nginx + Let's Encrypt  (traditional, more control)"
echo "    2) Caddy                  (simpler, auto-SSL)"
echo ""
read -p "  Enter choice [1/2] (default: 1): " PROXY_CHOICE
PROXY_CHOICE=${PROXY_CHOICE:-1}

echo ""
read -p "  Custom tracker script name (default: getinfo): " TRACKER_SCRIPT_NAME
TRACKER_SCRIPT_NAME=${TRACKER_SCRIPT_NAME:-getinfo}

# Sanitize tracker name — alphanumeric and hyphens only
TRACKER_SCRIPT_NAME=$(echo "$TRACKER_SCRIPT_NAME" | tr -cd 'a-zA-Z0-9-')
if [ -z "$TRACKER_SCRIPT_NAME" ]; then
    TRACKER_SCRIPT_NAME="getinfo"
fi

echo ""
success "Configuration collected"

# ──────────────────────────────────────────────
# Step 2: Generate credentials
# ──────────────────────────────────────────────

info "Step 2/7: Generating credentials"

CREDS_FILE="$DATA_DIR/credentials.txt"

# Preserve existing credentials on re-run
if [ -f "$CREDS_FILE" ]; then
    warn "Existing credentials found — reusing them"
    source <(grep -E '^(POSTGRES_|APP_SECRET)' "$CREDS_FILE" | sed 's/ //g')
fi

POSTGRES_DB="${POSTGRES_DB:-umami}"
POSTGRES_USER="${POSTGRES_USER:-umami}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(generate_secret 24)}"
APP_SECRET="${APP_SECRET:-$(generate_secret 32)}"

success "Credentials ready"

# ──────────────────────────────────────────────
# Step 3: Install Docker
# ──────────────────────────────────────────────

info "Step 3/7: Installing Docker"

if command -v docker &>/dev/null; then
    success "Docker already installed"
else
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    success "Docker installed"
fi

# Verify docker compose
if ! docker compose version &>/dev/null; then
    error "Docker Compose plugin not found. Please install Docker Compose v2."
fi

# ──────────────────────────────────────────────
# Step 4: Install reverse proxy
# ──────────────────────────────────────────────

info "Step 4/7: Setting up reverse proxy"

pkg_update

if [ "$PROXY_CHOICE" = "2" ]; then
    # Caddy
    if ! command -v caddy &>/dev/null; then
        if [ "$OS_FAMILY" = "debian" ]; then
            pkg_install debian-keyring debian-archive-keyring apt-transport-https
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
            apt-get update -qq
            pkg_install caddy
        elif [ "$OS_FAMILY" = "rhel" ]; then
            yum install -y yum-plugin-copr
            yum copr enable -y @caddy/caddy
            yum install -y caddy
        fi
    fi
    success "Caddy installed"
else
    # Nginx + certbot
    if ! command -v nginx &>/dev/null; then
        pkg_install nginx
    fi
    if ! command -v certbot &>/dev/null; then
        if [ "$OS_FAMILY" = "debian" ]; then
            pkg_install certbot python3-certbot-nginx
        elif [ "$OS_FAMILY" = "rhel" ]; then
            pkg_install certbot python3-certbot-nginx
        fi
    fi
    systemctl enable nginx
    success "Nginx + Certbot installed"
fi

# ──────────────────────────────────────────────
# Step 5: Deploy Umami
# ──────────────────────────────────────────────

info "Step 5/7: Deploying Umami"

mkdir -p "$DATA_DIR"

# Copy docker-compose.yml (uses ${VARIABLE} syntax — reads from .env at runtime)
cp "$INSTALL_DIR/templates/docker-compose.yml.template" "$DATA_DIR/docker-compose.yml"

# Generate .env with credentials
cat > "$DATA_DIR/.env" <<EOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
APP_SECRET=${APP_SECRET}
TRACKER_SCRIPT_NAME=${TRACKER_SCRIPT_NAME}
EOF
chmod 600 "$DATA_DIR/.env"

# Save credentials backup
cat > "$CREDS_FILE" <<EOF
# Umami Analytics Credentials
# Generated: $(date)
# Domain: ${DOMAIN}

POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
APP_SECRET=${APP_SECRET}
TRACKER_SCRIPT_NAME=${TRACKER_SCRIPT_NAME}

# Default Umami login (CHANGE THIS IMMEDIATELY):
# Username: admin
# Password: umami
EOF
chmod 600 "$CREDS_FILE"

# Start the stack
cd "$DATA_DIR"
docker compose up -d

# Wait for healthy
info "Waiting for Umami to start..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:3000/api/heartbeat &>/dev/null; then
        break
    fi
    sleep 2
done

if curl -sf http://localhost:3000/api/heartbeat &>/dev/null; then
    success "Umami is running"
else
    error "Umami failed to start. Check logs: docker compose -f $DATA_DIR/docker-compose.yml logs"
fi

# ──────────────────────────────────────────────
# Step 6: Configure SSL
# ──────────────────────────────────────────────

info "Step 6/7: Configuring SSL"

NGINX_CONF=$(nginx_config_path)

if [ "$PROXY_CHOICE" = "2" ]; then
    # Caddy — auto-SSL
    template "$INSTALL_DIR/templates/Caddyfile.template" /etc/caddy/Caddyfile
    systemctl restart caddy
    success "Caddy configured — SSL will auto-provision"
else
    # Nginx + certbot
    mkdir -p /var/www/certbot

    # Deploy HTTP-only config for initial cert provisioning
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Symlink for Debian-family (RHEL uses conf.d directly)
    if [ "$OS_FAMILY" != "rhel" ]; then
        ln -sf /etc/nginx/sites-available/umami /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    fi

    nginx -t && systemctl reload nginx

    # Get SSL cert — certbot modifies the nginx config to add the 443 block
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

    systemctl reload nginx
    success "SSL configured with Let's Encrypt"
fi

# ──────────────────────────────────────────────
# Step 7: Configure firewall
# ──────────────────────────────────────────────

info "Step 7/7: Configuring firewall"

if command -v ufw &>/dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 22/tcp
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable
    fi
    success "UFW firewall configured"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    success "Firewalld configured"
else
    warn "No firewall detected — make sure ports 80 and 443 are open"
fi

# ──────────────────────────────────────────────
# Done!
# ──────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              Setup Complete!                         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Your analytics dashboard: https://${DOMAIN}"
echo ""
echo "  Default login:"
echo "    Username: admin"
echo "    Password: umami"
echo ""
echo "  ⚠  CHANGE YOUR PASSWORD IMMEDIATELY after first login!"
echo ""
echo "  Credentials saved to: ${CREDS_FILE}"
echo "  Data directory: ${DATA_DIR}"
echo ""
echo "  Tracker script URL for your websites:"
echo "    https://${DOMAIN}/${TRACKER_SCRIPT_NAME}.js"
echo ""
echo "  Next steps:"
echo "    1. Log in and change your password"
echo "    2. Add your websites in Settings → Websites"
echo "    3. Add the tracking script to each site (see README)"
echo ""
