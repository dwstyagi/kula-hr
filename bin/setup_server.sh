#!/usr/bin/env bash
# One-time EC2 server setup for Kulahr (Ubuntu 22.04 LTS / t2.micro)
# Run as: ubuntu user via SSH after launching the EC2 instance.
#
# Usage:
#   ssh ubuntu@YOUR_EC2_IP "bash -s" < bin/setup_server.sh
#
# After this script completes, follow the manual steps at the bottom.

set -euo pipefail

RUBY_VERSION="4.0.1"
APP_DIR="/var/www/kulahr"
REPO_URL="https://github.com/dwstyagi/kula-hr.git"
APP_DOMAIN="kula-hr.com"

echo "=========================================="
echo " Kulahr — EC2 Server Setup"
echo " Ruby ${RUBY_VERSION} | Ubuntu 22.04"
echo "=========================================="

# ── 1. System packages ────────────────────────────────────────────────────────
echo "→ Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  git curl build-essential libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libpq-dev libvips libvips-dev \
  nginx postgresql-16 redis-server \
  acl libffi-dev

# ── 2. Swap (critical for t2.micro — 1 GB RAM is not enough without swap) ────
echo "→ Adding 2 GB swap..."
if ! swapon --show | grep -q /swapfile; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  # Tune swappiness — only use swap when memory is very low
  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
  sudo sysctl vm.swappiness=10
  echo "   Swap enabled."
else
  echo "   Swap already configured."
fi

# ── 3. rbenv + Ruby ───────────────────────────────────────────────────────────
echo "→ Installing rbenv + Ruby ${RUBY_VERSION}..."
if [ ! -d "$HOME/.rbenv" ]; then
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc
fi

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

rbenv install --skip-existing "$RUBY_VERSION"
rbenv global "$RUBY_VERSION"
gem install bundler --no-document

# ── 4. PostgreSQL — create user + database ───────────────────────────────────
echo "→ Configuring PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Prompt for DB password
read -rsp "Enter PostgreSQL password for 'kulahr' user: " DB_PASS
echo ""

sudo -u postgres psql -c "CREATE USER kulahr WITH PASSWORD '${DB_PASS}';" 2>/dev/null || \
  sudo -u postgres psql -c "ALTER USER kulahr WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -c "CREATE DATABASE kulahr_production OWNER kulahr;" 2>/dev/null || true

# ── 5. Redis — restrict to localhost ─────────────────────────────────────────
echo "→ Configuring Redis..."
sudo sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf
sudo sed -i 's/^# maxmemory .*/maxmemory 100mb/' /etc/redis/redis.conf
sudo sed -i 's/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
sudo systemctl enable redis-server
sudo systemctl restart redis-server

# ── 6. Clone repository ───────────────────────────────────────────────────────
echo "→ Cloning application..."
sudo mkdir -p "$(dirname "$APP_DIR")"
sudo chown ubuntu:ubuntu "$(dirname "$APP_DIR")"

if [ ! -d "$APP_DIR/.git" ]; then
  git clone "$REPO_URL" "$APP_DIR"
else
  echo "   Repository already cloned."
fi

cd "$APP_DIR"

# ── 7. Environment file ───────────────────────────────────────────────────────
echo "→ Creating /etc/kulahr.env..."
SECRET_KEY_BASE=$(openssl rand -hex 64)

sudo tee /etc/kulahr.env > /dev/null <<EOF
RAILS_ENV=production
APP_DOMAIN=${APP_DOMAIN}
DATABASE_URL=postgres://kulahr:${DB_PASS}@localhost/kulahr_production
REDIS_URL=redis://127.0.0.1:6379/0
SECRET_KEY_BASE=${SECRET_KEY_BASE}
RAILS_MAX_THREADS=2
WEB_CONCURRENCY=1
SIDEKIQ_CONCURRENCY=2
RAILS_LOG_TO_STDOUT=true
# SMTP — add these after creating your SMTP credentials:
# SMTP_HOST=smtp.sendgrid.net
# SMTP_PORT=587
# SMTP_USERNAME=apikey
# SMTP_PASSWORD=your_sendgrid_api_key
EOF

sudo chmod 600 /etc/kulahr.env

# You must add RAILS_MASTER_KEY manually:
echo ""
echo "⚠️  Add RAILS_MASTER_KEY to /etc/kulahr.env:"
echo "   sudo nano /etc/kulahr.env"
echo "   Paste: RAILS_MASTER_KEY=$(cat config/master.key 2>/dev/null || echo '<copy from config/master.key>')"

# ── 8. Install gems + precompile assets ──────────────────────────────────────
echo "→ Installing gems..."
bundle config set --local without 'development test'
bundle install --jobs 4 --retry 3

echo "→ Precompiling assets..."
RAILS_ENV=production bundle exec rails assets:precompile

echo "→ Running database migrations..."
RAILS_ENV=production bundle exec rails db:migrate

# ── 9. Systemd services ───────────────────────────────────────────────────────
echo "→ Installing systemd services..."
sudo cp config/systemd/puma.service /etc/systemd/system/puma.service
sudo cp config/systemd/sidekiq.service /etc/systemd/system/sidekiq.service

# Allow ubuntu user to restart puma/sidekiq without password (for CI/CD deploys)
echo "ubuntu ALL=(ALL) NOPASSWD: /bin/systemctl reload puma, /bin/systemctl restart puma, /bin/systemctl restart sidekiq" | \
  sudo tee /etc/sudoers.d/kulahr-deploy

sudo systemctl daemon-reload
sudo systemctl enable puma sidekiq
sudo systemctl start puma sidekiq

# ── 10. Nginx ─────────────────────────────────────────────────────────────────
echo "→ Configuring Nginx..."
sudo cp config/nginx/kulahr.conf /etc/nginx/sites-available/kulahr
sudo ln -sf /etc/nginx/sites-available/kulahr /etc/nginx/sites-enabled/kulahr
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo " Setup complete!"
echo "=========================================="
echo ""
echo "Checklist before going live:"
echo "  1. Add RAILS_MASTER_KEY to /etc/kulahr.env"
echo "  2. Create Platform Admin: RAILS_ENV=production rails console → PlatformAdmin.create!(email: ..., password: ...)"
echo "  3. Point Cloudflare DNS: kulahr.com → ${EC2_IP:-YOUR_EC2_IP} (A record, proxied)"
echo "                          *.kulahr.com → ${EC2_IP:-YOUR_EC2_IP} (A record, proxied)"
echo "  4. Set Cloudflare SSL/TLS → Flexible"
echo "  5. Add GitHub Secrets: EC2_HOST, EC2_SSH_KEY, (see README)"
echo ""
echo "Useful commands:"
echo "  sudo journalctl -u puma -f     # Puma logs"
echo "  sudo journalctl -u sidekiq -f  # Sidekiq logs"
echo "  sudo systemctl status puma"
echo "  cd /var/www/kulahr && bundle exec rails console -e production"
