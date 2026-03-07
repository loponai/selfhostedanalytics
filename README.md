# Self-Hosted Analytics

One-shot installation of [Umami](https://umami.is) analytics on any server (VPS, home PC, or any Linux machine). Privacy-friendly, cookieless, open source — track all your websites from a single dashboard you own.

```bash
curl -fsSL https://raw.githubusercontent.com/loponai/selfhostedanalytics/main/install.sh | sudo bash
```

> **No tracking scripts, no cookies, no data sold.** You own everything. GDPR compliant by default.

---

## Quick Start

### Step 1: Get a Server

You need a server (VPS, home PC, or any Linux machine) with root access. Umami is lightweight — 1GB RAM is the minimum, 2GB recommended. Any provider works (Hetzner, DigitalOcean, Linode, etc.), or use a spare machine at home.

| What you need | Minimum | Recommended |
|---------------|---------|-------------|
| CPU | 1 core | 2 cores |
| RAM | 1 GB | 2 GB |
| Storage | 20 GB | 50 GB |
| OS | Ubuntu 22.04 / Debian 12 | Ubuntu 24.04 |

### Step 2: Get a Domain & Point It

You need a subdomain for your analytics dashboard (optional if using Tailscale — see [Quick Start for Home Server](#quick-start-home-server-with-tailscale) below). Use any domain you own.

Go to your DNS provider (Cloudflare, Namecheap, etc.) and add an **A record**:

| Type | Name | Value | TTL | Proxy |
|------|------|-------|-----|-------|
| A | `analytics` | `YOUR_VPS_IP` | 3600 | Off (DNS only) |

This gives you `analytics.yourdomain.com` pointing to your VPS.

> **Important:** If using Cloudflare, set the proxy to **DNS only** (grey cloud) during setup so Let's Encrypt can verify your domain. You can enable the proxy after SSL is configured.

### Step 3: SSH In

**Mac/Linux:**
```bash
ssh root@YOUR_SERVER_IP
```

**Windows (PowerShell):**
```powershell
ssh root@YOUR_SERVER_IP
```

> **If something is already using ports 80/443** (like a control panel web server), disable it first:
> ```bash
> systemctl stop nginx && systemctl disable nginx
> ```

### Step 4: Run the Installer

One command. It handles everything — Docker, reverse proxy, SSL, database, Umami.

```bash
curl -fsSL https://raw.githubusercontent.com/loponai/selfhostedanalytics/main/install.sh | sudo bash
```

The installer will ask you:
1. **Your analytics domain** — e.g. `analytics.yourdomain.com`
2. **Your email** — for SSL certificate notifications
3. **Reverse proxy choice** — Nginx (traditional) or Caddy (simpler, auto-SSL)
4. **Tracker script name** — defaults to `getinfo` (avoids ad blocker detection)

The whole process takes about 2-3 minutes.

### Step 5: Log In

1. Go to `https://analytics.yourdomain.com`
2. Log in with the default credentials:
   - **Username:** `admin`
   - **Password:** `umami`
3. **Change your password immediately** — Settings → Profile → Change password

---

## What You Get

- **Real-time visitors** — see who's on your sites right now
- **Pageviews & unique visitors** — with trends over time
- **Bounce rate & session duration** — behavioral metrics most analytics miss
- **Referrer sources** — where your traffic comes from
- **UTM campaign tracking** — track marketing links (`?utm_source=...`)
- **Browser, OS, device, country** — visitor demographics
- **Custom events** — track button clicks, form submissions, purchases
- **Multiple websites** — one dashboard for all your sites
- **API access** — pull data programmatically for custom reports
- **No cookies** — GDPR/CCPA compliant without cookie banners
- **Ad blocker resistant** — custom script name + your own domain = nearly invisible to blockers

---

## Quick Start (Home Server with Tailscale)

If you want to run analytics on a home machine instead of renting a VPS, [Tailscale](https://tailscale.com/) makes it simple — no domain needed, no port forwarding, automatic SSL.

### Step 1: Install Docker

Follow the [official Docker install guide](https://docs.docker.com/engine/install/) for your distro, or use the convenience script:

```bash
curl -fsSL https://get.docker.com | sh
```

### Step 2: Run the Installer

```bash
curl -fsSL https://raw.githubusercontent.com/loponai/selfhostedanalytics/main/install.sh | sudo bash
```

When asked for a domain, enter any placeholder — you'll use your Tailscale URL instead.

### Step 3: Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up
```

Follow the link to authenticate your machine.

### Step 4: Expose with Tailscale Funnel

Your websites need to reach your analytics server publicly, so use Tailscale Funnel:

```bash
tailscale funnel 443
```

This gives you a public HTTPS URL like `https://your-machine.tail1234.ts.net`. Tailscale Funnel handles SSL automatically — no Let's Encrypt, no certificate renewal, no Nginx SSL config.

### Step 5: Use Your Tailscale URL

Use your Funnel URL as the analytics script source on your websites:

```html
<script defer src="https://your-machine.tail1234.ts.net/getinfo.js" data-website-id="YOUR_WEBSITE_ID"></script>
```

### What this means

- **No VPS cost** — use hardware you already own
- **No domain needed** — Tailscale Funnel provides a public HTTPS URL
- **Automatic SSL** — Tailscale handles certificates for you

---

## Adding Your Websites

### Step 1: Add a Site in Umami

1. Log into your Umami dashboard
2. Go to **Settings → Websites → Add website**
3. Enter your domain (e.g. `mysite.com`)
4. Copy the **Website ID** (a UUID like `a1b2c3d4-e5f6-...`)

### Step 2: Add the Tracking Script

Add the script to your website's `<head>`. The script name matches what you set during install (default: `getinfo`).

**Plain HTML:**
```html
<script defer src="https://analytics.yourdomain.com/getinfo.js" data-website-id="YOUR_WEBSITE_ID"></script>
```

**Next.js (App Router):**
```tsx
import Script from 'next/script'

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        <Script
          src="https://analytics.yourdomain.com/getinfo.js"
          data-website-id="YOUR_WEBSITE_ID"
          strategy="afterInteractive"
        />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

**Next.js (Pages Router):**
```tsx
import Script from 'next/script'

function MyApp({ Component, pageProps }) {
  return (
    <>
      <Script
        src="https://analytics.yourdomain.com/getinfo.js"
        data-website-id="YOUR_WEBSITE_ID"
        strategy="afterInteractive"
      />
      <Component {...pageProps} />
    </>
  )
}

export default MyApp
```

**WordPress:**

Add to your theme's `header.php` before `</head>`, or use a plugin like "Insert Headers and Footers":
```html
<script defer src="https://analytics.yourdomain.com/getinfo.js" data-website-id="YOUR_WEBSITE_ID"></script>
```

**Gatsby:**
```jsx
// gatsby-ssr.js
export const onRenderBody = ({ setHeadComponents }) => {
  setHeadComponents([
    <script
      key="umami"
      defer
      src="https://analytics.yourdomain.com/getinfo.js"
      data-website-id="YOUR_WEBSITE_ID"
    />,
  ])
}
```

> **Why `getinfo.js` instead of `umami.js`?** The default Umami script name appears on some ad blocker lists. By renaming it to something generic, your tracking script blends in as a first-party resource — especially since it's served from your own domain. This dramatically improves tracking accuracy for privacy-conscious audiences.

### Step 3: Verify

1. Open your website in a browser
2. Go to your Umami dashboard
3. You should see yourself as a real-time visitor

---

## Custom Event Tracking

Track specific user actions beyond pageviews:

```javascript
// Track a button click
document.getElementById('signup-btn').addEventListener('click', () => {
  umami.track('signup-click')
})
```

```javascript
// Track with custom data
umami.track('purchase', { plan: 'pro', price: 9.99 })
```

**React/Next.js:**
```tsx
<button onClick={() => umami.track('signup-click')}>Sign Up</button>

<button onClick={() => umami.track('purchase', { plan: 'pro', price: 9.99 })}>
  Buy Pro
</button>
```

---

## Admin Guide

### Everyday Commands

```bash
# Check status
cd /opt/umami && docker compose ps

# View logs
docker compose logs -f umami

# View database logs
docker compose logs -f db

# Restart everything
docker compose restart

# Stop everything
docker compose stop

# Start everything
docker compose up -d
```

### Update Umami

```bash
cd /opt/umami
docker compose pull
docker compose up -d
```

> Umami updates are backward-compatible. The database migrates automatically on startup.

### Backup Database

```bash
# Create a backup
cd /opt/umami
docker compose exec db pg_dump -U umami umami > backup_$(date +%Y%m%d).sql

# Restore from backup
docker compose exec -T db psql -U umami umami < backup_20260214.sql
```

### SSL Certificate Renewal

**Nginx + Let's Encrypt:**
```bash
# Test renewal
certbot renew --dry-run

# Force renewal
certbot renew --force-renewal
```

> Certbot sets up automatic renewal via systemd timer. You shouldn't need to do this manually.

**Caddy:** SSL renews automatically. No action needed.

### User Management

Umami manages users through its web interface:
- **Settings → Users → Add user** to create accounts
- Set users as Admin or regular User role
- Each user can have their own website assignments

### Key Files

| File | Purpose |
|------|---------|
| `/opt/umami/docker-compose.yml` | Docker stack configuration |
| `/opt/umami/.env` | Database credentials and settings |
| `/opt/umami/credentials.txt` | Generated credentials (read-only) |
| `/etc/nginx/sites-available/umami` | Nginx reverse proxy config |
| `/etc/caddy/Caddyfile` | Caddy reverse proxy config |
| `/opt/selfhostedanalytics/` | Installer files |

---

## Troubleshooting

**Umami won't start:**
```bash
cd /opt/umami
docker compose logs umami
# Check if the database is healthy
docker compose logs db
# Restart from scratch
docker compose down && docker compose up -d
```

**Can't reach the dashboard:**
```bash
# Check if Umami is responding locally
curl http://localhost:3000/api/heartbeat

# Check if nginx/caddy is running
systemctl status nginx   # or: systemctl status caddy

# Check firewall
ufw status              # Debian/Ubuntu
firewall-cmd --list-all # RHEL/CentOS
```

**SSL certificate issues:**
```bash
# Check certificate status
certbot certificates

# Re-run certificate provisioning
certbot --nginx -d analytics.yourdomain.com
```

**Port 80/443 already in use:**
```bash
# Check what's using the ports
ss -tlnp | grep -E ':80|:443'

# Disable the conflicting web server
systemctl stop nginx && systemctl disable nginx
```

**Database connection errors:**
```bash
# Check if postgres container is running
docker compose ps db

# Check postgres logs
docker compose logs db

# Verify credentials match
cat /opt/umami/.env
```

**Ad blockers still blocking the script:**
1. Make sure your analytics domain is on your **own domain** (not a third-party)
2. Verify the script name is set to something generic (not `umami` or `analytics`)
3. Check: `curl https://analytics.yourdomain.com/getinfo.js` should return JavaScript

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/loponai/selfhostedanalytics/main/uninstall.sh | sudo bash
```

Or if you cloned the repo:
```bash
sudo /opt/selfhostedanalytics/uninstall.sh
```

This removes all containers, configs, and data. Docker itself is left installed.

---

## Reference

### Requirements

- A server (VPS, home PC, or any Linux machine) with root access (1 GB RAM minimum)
- A domain or subdomain pointing to your server (optional if using Tailscale Funnel)
- Ports 80 and 443 open

### Architecture

```
┌─────────────────────────────────────────────────┐
│                   Your Server                     │
│                                                  │
│  ┌──────────┐    ┌──────────┐    ┌───────────┐  │
│  │  Nginx/  │───▶│  Umami   │───▶│ PostgreSQL│  │
│  │  Caddy   │    │  :3000   │    │   :5432   │  │
│  │  :80/443 │    └──────────┘    └───────────┘  │
│  └──────────┘                                    │
│       ▲                                          │
└───────│──────────────────────────────────────────┘
        │
   HTTPS traffic
   from your websites
```

### Ports

| Port | Service | Exposed |
|------|---------|---------|
| 80 | HTTP (redirect to HTTPS) | Yes |
| 443 | HTTPS (reverse proxy) | Yes |
| 3000 | Umami (localhost only) | No — bound to 127.0.0.1, proxied |
| 5432 | PostgreSQL (internal) | No — Docker only |

### File Layout

```
/opt/selfhostedanalytics/     ← Installer files
├── install.sh
├── setup.sh
├── uninstall.sh
└── templates/
    ├── docker-compose.yml.template
    ├── nginx.conf.template
    └── Caddyfile.template

/opt/umami/                   ← Runtime data
├── docker-compose.yml        ← Generated from template
├── .env                      ← Your credentials
└── credentials.txt           ← Generated credentials backup
```

---

## License

MIT — do whatever you want with it.
