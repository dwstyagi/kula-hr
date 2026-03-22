# Deployment & Debugging Guide

## Server Details

| Item | Value |
|------|-------|
| Provider | AWS EC2 t3.micro |
| OS | Ubuntu 24.04 LTS |
| IP | 13.200.249.229 |
| Domain | https://kula-hr.com |
| App directory | `/var/www/kulahr` |
| Env file | `/etc/kulahr.env` |

## SSH Access

```bash
ssh kulahr
# or
ssh -i ~/Downloads/kulahr.pem ubuntu@13.200.249.229
```

---

## Services

| Service | Purpose | Port |
|---------|---------|------|
| Nginx | Reverse proxy | 80 |
| Puma | Rails app server | 3000 (localhost only) |
| Sidekiq | Background jobs | — |
| PostgreSQL | Database | 5432 (localhost only) |
| Redis | Cache + job queue | 6379 (localhost only) |

---

## Common Commands

### Check service status
```bash
sudo systemctl status puma
sudo systemctl status sidekiq
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status redis-server
```

### View live logs
```bash
sudo journalctl -u puma -f          # Puma (Rails) logs
sudo journalctl -u sidekiq -f       # Sidekiq logs
sudo journalctl -u nginx -f         # Nginx logs
sudo journalctl -u postgresql -f    # PostgreSQL logs
```

### Restart services
```bash
sudo systemctl restart puma
sudo systemctl restart sidekiq
sudo systemctl reload nginx         # graceful — no downtime
sudo systemctl restart redis-server
```

### Zero-downtime Puma reload
```bash
sudo systemctl reload puma          # sends SIGUSR1 — workers finish current requests
```

---

## Rails Console (Production)

```bash
ssh kulahr
cd /var/www/kulahr
set -a; source /etc/kulahr.env; set +a
RAILS_ENV=production bundle exec rails console
```

---

## Database

### Connect to PostgreSQL
```bash
set -a; source /etc/kulahr.env; set +a
psql $DATABASE_URL
```

### Run migrations manually
```bash
cd /var/www/kulahr
set -a; source /etc/kulahr.env; set +a
RAILS_ENV=production bundle exec rails db:migrate
```

### Check migration status
```bash
RAILS_ENV=production bundle exec rails db:migrate:status
```

---

## Deployment (Manual)

If GitHub Actions fails, deploy manually:

```bash
ssh kulahr
cd /var/www/kulahr
git pull origin main
bundle config set --local without 'development test'
bundle install --jobs 4 --retry 3
SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile
set -a; source /etc/kulahr.env; set +a
RAILS_ENV=production bundle exec rails db:migrate
sudo systemctl reload puma
sudo systemctl restart sidekiq
```

---

## Environment Variables

View current env:
```bash
sudo cat /etc/kulahr.env
```

Edit env:
```bash
sudo nano /etc/kulahr.env
sudo systemctl restart puma sidekiq   # restart after changes
```

Key variables:
| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Decrypts Rails credentials |
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis connection string |
| `SECRET_KEY_BASE` | Rails session encryption |
| `APP_DOMAIN` | Primary domain (`kula-hr.com`) |
| `SERVER_IP` | EC2 IP for Rails host authorization |

---

## Nginx

### Config location
```
/etc/nginx/sites-available/kulahr  (source)
/etc/nginx/sites-enabled/kulahr    (symlink)
```

### Test and reload
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Update config from repo
```bash
sudo cp /var/www/kulahr/config/nginx/kulahr.conf /etc/nginx/sites-available/kulahr
sudo nginx -t && sudo systemctl reload nginx
```

---

## Disk & Memory

```bash
df -h          # disk usage
free -h        # memory + swap usage
htop           # live process monitor (press q to quit)
```

If memory is critical:
```bash
sudo systemctl stop sidekiq    # free ~100MB
```

---

## Common Issues

### App returns 502 Bad Gateway
Puma is down. Check logs and restart:
```bash
sudo journalctl -u puma -n 50 --no-pager
sudo systemctl restart puma
```

### Blocked host error
A new domain/IP needs to be added to `/etc/kulahr.env`:
```bash
echo "SERVER_IP=NEW_IP" | sudo tee -a /etc/kulahr.env
sudo systemctl restart puma
```

### Assets not loading (404)
Re-run asset precompile:
```bash
cd /var/www/kulahr
set -a; source /etc/kulahr.env; set +a
SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile
sudo systemctl reload puma
```

### Sidekiq jobs not running
```bash
sudo journalctl -u sidekiq -n 50 --no-pager
sudo systemctl restart sidekiq
```

### EC2 IP changed (after stop/start)
1. Update SSH config: `sed -i '' 's/OLD_IP/NEW_IP/' ~/.ssh/config`
2. Update GitHub secret `EC2_HOST` with new IP
3. Update Cloudflare DNS A records to new IP
4. Update `/etc/kulahr.env` → `SERVER_IP=NEW_IP` on server

### SSH hangs
Check AWS security group — your IP may have changed:
- Google "what is my ip"
- **AWS → EC2 → Security Groups → Edit inbound rules → SSH → update to your IP**

---

## GitHub Actions CI/CD

Pipeline: `.github/workflows/deploy.yml`

| Secret | Purpose |
|--------|---------|
| `EC2_HOST` | Server IP |
| `EC2_SSH_KEY` | Private key (contents of kulahr.pem) |

Triggers on push to `main` — runs tests first, then deploys if tests pass.

View pipeline: **GitHub repo → Actions tab**
