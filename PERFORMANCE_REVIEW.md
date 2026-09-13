# Performance and reliability review fixes

This change addresses the 20 findings from the September 13 review, together with the initial performance review fixes. P1 findings can lose work or change payroll/leave results; P2 findings increase memory, latency, or retry risk as data grows; P3 findings affect browser lifecycle and regression protection.

## Problems and changes

| Finding | Problem in simple words | Change |
| --- | --- | --- |
| P1-01 | A full Redis cache could evict queued jobs. | Separate disposable cache Redis from job Redis; use `noeviction` for the queue. |
| P1-02 | A worker could start before payroll committed, or queue failure could leave committed payroll with no job. | Persist a dispatch record with the business transaction; publish after commit, recover unacknowledged work, and exclude duplicate payroll workers with a session lock. |
| P1-03 | Resetting a payroll removed the payslip but left its leave encashment marked paid. | Restore attached encashments to approved when clearing payslips, so recalculation includes them again. |
| P1-04 | April rollover wrote balances into the following year. | Derive explicit source and destination financial years from the opening date; seed April once. |
| P2-01 | Completed payslips stayed attached to the parent run in memory. | Create records directly rather than accumulating them through the parent's collection; process employee batches. |
| P2-02 | Reports and downloads assembled every employee in memory. | Limit report previews to 50 rows; stream complete bank/report exports; write XLSX rows directly into a temporary ZIP file in batches of 100. |
| P2-03 | XLSX limits were checked after the workbook had been loaded. | Preflight expanded size, worksheet rows, cell coordinates, and shared strings before Roo opens it; then parse rows through the streaming API. |
| P2-04 | Attendance CSV uploads occupied a web request and ran queries per employee. | Queue bounded uploads; parse 100 rows at a time; bulk-read employees/summaries and use one conditional update per batch. |
| P2-05 | Attendance could be changed after another request locked it. | Reload and authorize interactive edits under a row lock; bulk writes update draft rows only at SQL execution time. |
| P2-06 | Retried payroll work recalculated employees already paid by that run. | Exclude employees with committed payslips and resume progress; serialize duplicate workers for the same run. |
| P2-07 | Final processed counts included skipped employees. | Persist the actual number of resulting payslips when processing finishes. |
| P2-08 | Off-cycle creation built a form row for the entire workforce. | Fetch at most 50 matching employees, preserve entered amounts across searches, bound submissions, and batch off-cycle/F&F processing. |
| P2-09 | Checking payroll readiness loaded the entire workforce. | Use SQL relations/counts for the creation gate and at most 50 detailed employees per displayed group. |
| P2-10 | Re-running monthly leave accrual credited leave again. | Insert a unique tenant/month ledger entry in the same transaction as the credit; rollback permits retry. |
| P2-11 | Employee numbering sorted text incorrectly after EMP9999. | Initialize a numeric tenant sequence from existing codes and share a locked allocator between ordinary creation and imports. |
| P2-12 | ZIP generation had no usable enqueue path and files could be stale or accumulate. | Queue generation from the download action, write atomically, fingerprint report inputs, discard changed versions, and expire ZIP/partial files after one day. |
| P2-13 | The platform dashboard loaded all companies to display five. | Rank/count in SQL and load only displayed records. |
| P3-01 | Payroll guide navigation left a keyboard listener attached. | Remove its listener and scroll lock on disconnect. |
| P3-02 | A hidden task tab stopped polling permanently. | Reschedule while hidden, resume on visibility, and clear timers/listeners on disconnect. |
| P3-03 | Pull requests did not run the browser lifecycle checks. | Add PR/main verification for Rails, JavaScript lifecycle checks, and the real-commit dispatch probe. Deployment remains separately invoked. |

The earlier fixes also batch salary inputs and attendance generation, aggregate YTD in SQL, cache fingerprinted individual PDFs, paginate attendance/calendars/import previews, queue imports and payroll resets, and release browser listeners/observers on navigation.

## Reproduce validation

Use a local disposable `hrms_test` PostgreSQL database. RSpec clears that test database. Run the probes after RSpec, not concurrently with it.

```sh
RAILS_ENV=test bundle exec rails db:prepare
bundle exec rails tailwindcss:build
bundle exec rspec
node --test spec/javascript/*.cjs
bundle exec rails runner -e test script/reliable_dispatch_review.rb
bundle exec rails runner -e test script/performance_review.rb
```

Local result: **1,288 RSpec examples, zero failures; six JavaScript tests, zero failures**. The independent dispatch probe verifies commit visibility across connections, rollback without publication, and exclusion/release of a duplicate payroll worker. Tailwind compilation and changed-file Ruby lint also pass.

Focused regression suites cover queue delivery failure/recovery, monthly accrual rollback/replay, EMP10000, encashment reset/recalculation, resumed payroll, retained associations, bounded readiness, XLSX round-trip/sparse-cell rejection, exports across batch boundaries, attendance lock timing, and ZIP invalidation/cleanup. See `spec/performance`, `spec/jobs`, the affected service/request specs, and `spec/javascript`.

| Scenario | Original queries | Final queries |
| --- | ---: | ---: |
| PF report, 25 employees | 55 | 5 |
| ESI report, 25 employees | 28 | 5 |
| PT report, 25 employees | 29 | 6 |
| Salary calculation, 25 employees | 226 | 9 |
| Regenerate already locked attendance, 25 employees | 77 | 1 |
| PDF generation, five employees | 55 | 11 |
| Reset payroll, 25 employees / 100 line items | 203 | 6 |

YTD now instantiates **zero payslip or line-item objects**, including the 12-month case that previously instantiated 300 payslips and 1,200 items. Query counts grow by batch for larger datasets. The original counts come from the supplied baseline; final counts come from the committed probe on the same fixture shape. Local timing is not a production latency or peak-RSS guarantee. Validate production-size data and concurrent load on staging before rollout.

## Runtime limits and behaviour

- Employee imports: 1,000 employees, 10 MB compressed, 25 MB expanded, template-width columns and 2,000 characters per cell. Preview pages hold ten employees.
- Attendance imports: 2 MB and 10,000 rows; errors are capped at 100 messages. Valid rows can complete with warnings; a raised job failure rolls back the task and retains inputs for retry.
- Off-cycle creation: 50 search matches at a time and at most 500 entries per submission. Previously entered positive amounts are preserved when searching.
- Statutory report pages and readiness details: 50 employees per page/group; counts and report summaries describe the full scope. Downloads include all matching employees.
- A queued job is delivered at least once. Dispatches are deduplicated by job class/arguments and acknowledged after handling; a five-minute dispatch lease allows recovery after worker loss. Payroll resumes committed employees. Import/generation/reset tasks commit their work with task completion.
- ZIPs are local to the host, available for one day, and regenerated when their input fingerprint changes. The current deployment runs web and worker on the same host; multiple hosts require shared artifact storage. Use the download action again after generation finishes.

## Production rollout requirements

These are deployment changes, not changes applied to a live server by this PR. Do **not** rerun the full first-install setup script on an existing installation: it creates the environment file.

For the existing `/var/www/kulahr` installation:

1. Drain/stop workers and prevent payroll mutations during the upgrade. Apply the three new migrations with the existing production environment loaded. This creates background tasks, durable dispatches, monthly accrual markers, and the employee sequence.
2. Keep `REDIS_URL` on the queue instance (port 6379). Set that instance's `maxmemory-policy noeviction` in `/etc/redis/redis.conf` and reload/restart Redis according to the host's maintenance procedure. Preserve queue persistence and existing data. Queue memory exhaustion should reject writes, allowing the database outbox to retry after capacity returns.
3. Copy `config/redis-cache.conf` to `/etc/redis/hrms-cache.conf`, install `config/systemd/redis-cache.service`, and add `CACHE_REDIS_URL=redis://127.0.0.1:6380/0` to the existing `/etc/kulahr.env`. Start this separate cache instance; its `allkeys-lru` eviction cannot remove queue keys. Budget memory for both instances and workers; the supplied defaults cap each Redis instance at 100 MB.
4. Install `config/systemd/hrms-dispatch.service` and `.timer`; run `systemctl daemon-reload`, then enable/start `redis-cache` and `hrms-dispatch.timer`. The timer retries outbox delivery independently of Sidekiq's Redis-backed scheduler. Adapt user/path values if the host differs from the existing Ubuntu deployment.
5. Restart web and workers using the new code. Verify Redis policies/ports, the recovery timer, a small attendance task, payroll completion, and ZIP generation/download. Monitor pending dispatch age/attempts, task failures, queue depth, Redis memory, worker RSS, and available disk space.

Before re-enabling the monthly schedule during a mid-month upgrade, reconcile whether that month's accrual was already applied under the old code. If it was, record the corresponding `leave_accruals` tenant/period marker so a retry cannot credit it again. Reconcile any previously incorrect April balances or missing encashment payouts separately against approved records; this PR prevents recurrence and does not infer historical financial corrections.
