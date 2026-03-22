# Kula HR — Multi-Tenant HRMS & Payroll for Indian Companies

A SaaS application that lets Indian companies manage employee payroll end-to-end — from salary structures and attendance to statutory compliance (PF, ESI, PT, TDS) and payslip generation.

**Live:** https://kula-hr.com

---

## What It Does

```
Company signs up → Add employees → Configure salary structures
→ Track attendance & leaves → Run payroll every month
→ System calculates PF, ESI, PT, TDS automatically
→ Generate payslips → Download bank file → Pay via bank
```

---

## Three Portals

| Portal | URL | Who Uses It |
|--------|-----|-------------|
| Platform Admin | `kula-hr.com/platform_admin` | SaaS owner — monitors all tenants |
| HR Admin | `company.kula-hr.com/admin` | HR team — manages employees, payroll, leaves |
| Employee | `company.kula-hr.com/portal` | Staff — views payslips, applies leave, submits tax |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Ruby 4.0.1 |
| Framework | Rails 8.1.2 |
| Database | PostgreSQL 16 |
| Cache + Queue | Redis 7 |
| Background Jobs | Sidekiq |
| Web Server | Puma 7 + Nginx |
| Frontend | Tailwind CSS v4, Hotwire (Turbo + Stimulus) |
| Multi-tenancy | acts_as_tenant (subdomain-based) |
| Auth | Devise + devise_invitable |
| Authorization | Pundit + Rolify |
| State Machine | AASM (payroll lifecycle) |
| PDF | Prawn + Prawn Table |
| Audit Trail | PaperTrail |
| Charts | Chartkick + Groupdate |
| Testing | RSpec + FactoryBot + Shoulda Matchers |
| CI/CD | GitHub Actions |
| Hosting | AWS EC2 t3.micro + Cloudflare |

---

## Indian Statutory Compliance

| Compliance | Rate | Notes |
|-----------|------|-------|
| PF (EPF) | 12% employee + 12% employer | Capped at ₹15,000 basic |
| ESI | 0.75% employee + 3.25% employer | Applicable if gross ≤ ₹21,000 |
| Professional Tax | State-specific slabs | 7 states supported |
| TDS | Old regime (0/5/20/30%) or New regime (0/5/10/15/20/30%) | Standard deduction ₹75,000 |

---

## Trial vs Active Feature Gating

| Feature | Trial | Active |
|---------|-------|--------|
| Employees (manual) | Up to 10 | Unlimited |
| Bulk Import | ❌ | ✅ |
| Leave & Attendance | ✅ | ✅ |
| Payroll Processing | ✅ | ✅ |
| Bank File Download | ❌ | ✅ |
| Payslip PDF (bulk) | ❌ | ✅ |
| Reports | ✅ | ✅ |

Suspended/Cancelled tenants get read-only access across the board.

---

## Local Development

### Prerequisites
- Ruby 4.0.1 (via rbenv)
- PostgreSQL 16
- Redis 7
- Bundler 4

### Setup

```bash
git clone https://github.com/dwstyagi/kula-hr.git
cd kula-hr
bundle install
cp .env.example .env          # fill in values
rails db:create db:migrate db:seed
bin/dev                       # starts Rails + Tailwind watcher
```

### Subdomains (local)

The app uses `lvh.me` for local subdomain routing:

```
lvh.me:3000/platform_admin      → Platform Admin
acme.lvh.me:3000/admin          → HR Admin (tenant: acme)
acme.lvh.me:3000/portal         → Employee Portal (tenant: acme)
```

### Create a Platform Admin (local)

```bash
rails console
PlatformAdmin.create!(email: "admin@example.com", password: "password123")
```

---

## Payroll Lifecycle (AASM)

```
draft → processing → processed → under_review → approved → paid
                                              ↘ rejected
```

---

## Background Jobs (Sidekiq)

| Job | Trigger |
|-----|---------|
| Payroll processing | Manual (HR triggers) |
| Bulk payslip PDF | After payroll approved |
| Employee invitation emails | On invite |

Start Sidekiq locally:
```bash
bundle exec sidekiq
```

---

## Testing

```bash
bundle exec rspec                      # all tests
bundle exec rspec spec/models          # models only
bundle exec rspec spec/requests        # request specs
bundle exec rspec --format documentation
```

Test coverage report generated at `coverage/index.html`.

---

## Deployment

**Infrastructure:** AWS EC2 t3.micro + Cloudflare (free tier)

```
Browser → Cloudflare (SSL) → Nginx (port 80) → Puma (port 3000)
                                              → Sidekiq
PostgreSQL + Redis run on the same EC2 instance
```

See [`config/DEPLOYMENT.md`](config/DEPLOYMENT.md) for full debugging and ops guide.

### CI/CD (GitHub Actions)

Push to `main` → runs RSpec → deploys to EC2 via SSH if tests pass.

Pipeline: `.github/workflows/deploy.yml`

Required GitHub secrets:

| Secret | Value |
|--------|-------|
| `EC2_HOST` | EC2 public IP |
| `EC2_SSH_KEY` | Private key (contents of `.pem` file) |

### Manual Deploy

```bash
ssh kulahr
cd /var/www/kulahr
git pull origin main
bundle config set --local without 'development test'
bundle install --jobs 4
SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile
set -a; source /etc/kulahr.env; set +a
RAILS_ENV=production bundle exec rails db:migrate
sudo systemctl reload puma
sudo systemctl restart sidekiq
```

---

## Project Structure

```
app/
├── controllers/
│   ├── admin/            # HR Admin portal
│   ├── employee_portal/  # Employee portal
│   ├── platform/         # Platform Admin
│   └── home_controller.rb
├── models/
├── policies/             # Pundit authorization
├── services/
│   ├── statutory/        # PF, ESI, PT, TDS calculators
│   └── payroll/          # Salary calculator, processor, PDF, bank files
└── views/
config/
├── DEPLOYMENT.md         # Ops & debugging guide
├── nginx/kulahr.conf     # Nginx config
└── systemd/              # Puma + Sidekiq service files
```

---