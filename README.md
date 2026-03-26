# Kula HR

Kula HR is a multi-tenant HRMS and payroll application built for Indian payroll workflows. It covers tenant onboarding, employee management, leave and attendance, salary structures, payroll processing, payslips, statutory deductions, reports, and bank file generation.

Production: https://kula-hr.com

## Overview

Kula HR is organized around three user-facing surfaces:

| Surface | URL pattern | Purpose |
| --- | --- | --- |
| Marketing site | `kula-hr.com` | Product pages and tenant signup |
| Platform admin | `kula-hr.com/platform_admin` | SaaS operator tools |
| Tenant app | `tenant.kula-hr.com` | HR admin and employee self-service |

Tenant data is isolated with subdomain-based multitenancy and row-level scoping through `acts_as_tenant`.

## Core Capabilities

- Tenant onboarding with seeded payroll defaults
- Role-based access for platform admins, tenant super admins, HR admins, and employees
- Employee directory, invitations, activation links, salary assignment, and bulk import/export
- Leave types, leave requests, leave balances, attendance summary generation, and attendance template upload
- Payroll runs with draft, review, approval, rejection, reprocessing, and payment states
- Payslip generation, inline revision, PDF download, ZIP export, and bank file generation
- Statutory calculations for PF, ESI, Professional Tax, and TDS
- Dashboards, compliance reports, and YTD earnings reporting
- Real-time payroll progress and leave notifications using Turbo and Action Cable

## Tech Stack

| Layer | Choice |
| --- | --- |
| Language | Ruby 4.0.1 |
| Framework | Rails 8.1.2 |
| Database | PostgreSQL |
| Background jobs | Sidekiq + Redis |
| Frontend | ERB, Tailwind CSS, Hotwire (Turbo + Stimulus), Importmap |
| Auth | Devise, Devise Invitable |
| Authorization | Pundit + Rolify |
| Multitenancy | `acts_as_tenant` |
| Workflow state | AASM |
| Auditing | PaperTrail |
| Testing | RSpec, FactoryBot |

## Architecture

### Multitenancy

- Each company gets its own subdomain, for example `acme.kula-hr.com`.
- Tenant context is resolved from the request subdomain in `ApplicationController`.
- Tenant-scoped models use `acts_as_tenant :tenant`.
- Background jobs and services that run outside request scope wrap work in `ActsAsTenant.with_tenant`.

### Portals

- `Platform::` controllers handle operator workflows outside tenant scope.
- `Admin::` controllers handle tenant HR and payroll operations.
- `EmployeePortal::` controllers handle employee self-service.

### Business Logic

Most business rules live in service objects under `app/services`, with major areas split into:

- `attendance`
- `employees`
- `leave`
- `payroll`
- `reports`
- `salary`
- `statutory`
- `tenants`

## Key Business Rules

- Payroll is processed per tenant, per month, with one `PayrollRun` allowed for a given month and year.
- Attendance must be locked before payroll can be created for a month.
- Payroll approval and rejection are restricted to tenant super admins.
- Payslips can be revised after processing; payroll totals are recalculated after edits.
- TDS calculations use the Indian financial year (`April` through `March`) and account for employee tax declarations.
- Leave and attendance feed payroll through a locked monthly `AttendanceSummary`, not through raw leave data.

## Getting Started

### Requirements

Make sure the following are installed and running locally:

- Ruby `4.0.1`
- Bundler
- PostgreSQL
- Redis

Node.js is not required for the standard local workflow because the app uses Importmap and `tailwindcss-rails`.
PostgreSQL and Redis are not started by `bin/dev`, so start them separately before booting the app.

### Setup

1. Install gems:

```bash
bundle install
```

2. Prepare the database:

```bash
bin/rails db:prepare
```

3. Optionally load demo data:

```bash
bin/rails db:seed
```

4. Start the app:

```bash
bin/dev
```

`bin/dev` starts:

- Rails server
- Tailwind watcher
- Sidekiq worker

If you want a one-command bootstrap, use:

```bash
bin/setup
```

For setup without starting the app:

```bash
bin/setup --skip-server
```

## Local Development URLs

In development, subdomains are served via `lvh.me`, which resolves to `127.0.0.1`.

| Area | URL |
| --- | --- |
| Marketing site | `http://lvh.me:3000` |
| Platform admin login | `http://lvh.me:3000/platform_admin/login` |
| Tenant admin | `http://acme.lvh.me:3000/admin` |
| Employee portal | `http://acme.lvh.me:3000/portal` |
| Letter Opener | `http://lvh.me:3000/letter_opener` |

## Seed Data

If you run `bin/rails db:seed`, the app creates a sample platform admin and a sample tenant.

### Demo Credentials

| Role | Email | Password |
| --- | --- | --- |
| Platform admin | `admin@kulahr.com` | `password123` |
| Tenant super admin | `admin@acme.com` | `password123` |

The sample tenant uses the `acme` subdomain and includes departments, designations, employees, and sample bank details.

## Typical Payroll Flow

1. Configure payroll settings, salary components, and salary structures.
2. Create or import employees and assign salaries.
3. Approve leave and generate monthly attendance summaries.
4. Lock attendance for the payroll month.
5. Create a payroll run.
6. Process payroll in the background through Sidekiq.
7. Review payslips and resubmit if corrections are needed.
8. Approve payroll, lock payslips, and generate bank files.
9. Mark the payroll run as paid.

## Testing and Quality Checks

Run the core test suite:

```bash
bundle exec rspec
```

Run linting:

```bash
bin/rubocop
```

Run security checks:

```bash
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/importmap audit
```

Build Tailwind assets manually if needed:

```bash
bundle exec rails tailwindcss:build
```

CI/CD is defined in `.github/workflows/deploy.yml`. The workflow runs RSpec and can deploy to EC2 when manually dispatched from `main`.

## Repository Structure

```text
app/
  controllers/
    admin/
    employee_portal/
    platform/
  models/
  policies/
  services/
    attendance/
    employees/
    leave/
    payroll/
    reports/
    salary/
    statutory/
    tenants/
  jobs/
  mailers/
  views/
spec/
config/
db/
```

## Background Jobs and Realtime

- Sidekiq queues are configured in `config/sidekiq.yml`.
- Payroll processing runs on the dedicated `payroll` queue.
- Mail delivery runs through Sidekiq in development and production.
- Payroll progress uses Turbo Streams.
- Leave notifications use Action Cable.
- Development uses the async cable adapter; production uses Redis.

## Deployment

The primary deployment path is:

- GitHub Actions
- SSH to AWS EC2
- Puma + Sidekiq behind Nginx
- PostgreSQL + Redis on the host

Useful references:

- Runbook: `config/DEPLOYMENT.md`
- Deployment workflow: `.github/workflows/deploy.yml`
- Production image build: `Dockerfile`

### Important Production Environment Variables

- `RAILS_MASTER_KEY`
- `DATABASE_URL`
- `REDIS_URL`
- `SECRET_KEY_BASE`
- `APP_DOMAIN`
- `SERVER_IP`

## Useful Commands

```bash
# Start app, Tailwind watcher, and Sidekiq
bin/dev

# Prepare database
bin/rails db:prepare

# Seed demo data
bin/rails db:seed

# Run specs
bundle exec rspec

# Open Rails console
bin/rails console

# Start Sidekiq manually
bundle exec sidekiq -C config/sidekiq.yml
```

## Notes for Contributors

- The app is server-rendered by default; prefer following existing Rails and Hotwire patterns.
- Business rules are generally implemented in service objects, not controllers.
- When changing payroll logic, review both payroll processing and salary preview paths.
- When changing tenant-scoped behavior, verify `acts_as_tenant` and policy coverage.
- Request specs and service specs provide the best starting point for regression coverage.
