#!/bin/bash
set -e

# Self-Hosted Analytics Installer
# One-shot Umami analytics setup for any VPS
# https://github.com/loponai/selfhostedanalytics

REPO="https://github.com/loponai/selfhostedanalytics.git"
INSTALL_DIR="/opt/selfhostedanalytics"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         Self-Hosted Analytics Installer              ║"
echo "║         Umami + PostgreSQL + SSL                     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (sudo)"
    exit 1
fi

# Detect OS family
if [ -f /etc/debian_version ]; then
    OS_FAMILY="debian"
    echo "Detected: Debian/Ubuntu"
elif [ -f /etc/redhat-release ]; then
    OS_FAMILY="rhel"
    echo "Detected: RHEL/CentOS/AlmaLinux"
else
    echo "Warning: Unknown OS. Proceeding anyway..."
    OS_FAMILY="unknown"
fi

# Install git if not present
if ! command -v git &>/dev/null; then
    echo "Installing git..."
    if [ "$OS_FAMILY" = "debian" ]; then
        apt-get update -qq && apt-get install -y -qq git
    elif [ "$OS_FAMILY" = "rhel" ]; then
        yum install -y -q git
    fi
fi

# Clone or update the repo
if [ -d "$INSTALL_DIR" ]; then
    echo "Existing installation found at $INSTALL_DIR"
    echo "Updating..."
    cd "$INSTALL_DIR" && git pull --quiet
else
    echo "Cloning installer..."
    git clone --quiet "$REPO" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
chmod +x setup.sh uninstall.sh

echo ""
echo "Running setup..."
echo ""

exec bash setup.sh
