---
title: "Payroll Processing in India: Complete Guide for Employers [2026]"
description: "Complete guide to payroll processing in India — salary inputs, attendance lock, gross pay, PF, ESI, Professional Tax and TDS calculations, bank transfer, statutory due dates and payslips."
summary: "Payroll in India is eight steps that have to happen in order. Here is the full sequence, what breaks at each stage, and the checks worth making before money leaves your account."
published_on: 2026-08-06
updated_on: 2026-08-06
category: "Payroll process"
weight: 1

takeaways:
  - "Indian payroll is a fixed sequence of eight steps — most errors come from doing them out of order, not from bad arithmetic."
  - "Attendance must be locked before salaries are calculated, and a locked run should never be reopened after payment."
  - "Four statutory deductions apply: PF, ESI, Professional Tax and TDS — each with its own base, threshold and due date."
  - "TDS is a projection of annual tax spread across the year, not a flat monthly percentage, so late declarations cause year-end spikes."
  - "The review gate belongs before payment: check variance, zero net pay, joiners, exits and threshold crossings."

faqs:
  - question: "What are the steps in the Indian payroll process?"
    answer: "Freeze the employee and salary master, lock attendance and leave, calculate gross earnings, apply statutory deductions (PF, ESI, Professional Tax and TDS), review net pay, pay salaries through a bank file, deposit statutory dues, and publish payslips. The order matters — every step inherits data from the one before it."
  - question: "What is the difference between CTC, gross salary and net salary?"
    answer: "CTC is the total cost to the employer, including employer PF, employer ESI and often a gratuity provision. Gross salary is the sum of the employee's earnings before deductions. Net salary is gross minus employee deductions, and is the amount actually credited to the bank account. CTC is always the largest of the three and is not what the employee receives."
  - question: "Which deductions are mandatory in Indian payroll?"
    answer: "Provident Fund and ESI apply based on wage thresholds and establishment coverage, Professional Tax applies in states that levy it, and TDS on salary applies where the employee's projected annual income is taxable. Applicability depends on your establishment type, headcount and the states you employ people in."
  - question: "Can a payroll run be edited after salaries are paid?"
    answer: "It should not be. Once salaries are disbursed and statutory dues deposited, the run is a financial record that returns and payslips are built on. Corrections belong in the following month's payroll as arrears or recovery, which keeps the audit trail intact."
  - question: "When are PF, ESI and TDS payments due?"
    answer: "Salary TDS is generally due by the 7th of the following month, with March generally due 30 April for non-government deductors. EPF and ESI contributions are generally due within 15 days of the close of the month. Professional Tax frequency varies by state. Confirm each against current official notifications before depositing."
---

Most payroll problems are not calculation problems. The arithmetic behind Provident Fund or Professional Tax is simple enough to do on paper. What goes wrong is sequence — attendance gets finalised after salaries are computed, a mid-month increment arrives once the sheet is locked, or a new joiner crosses a statutory threshold that nobody re-checked.

This guide walks through the Indian payroll process in the order it actually has to happen, and points out where each step tends to break.

<figure>
<svg viewBox="0 0 760 190" role="img" aria-label="Diagram of the Indian payroll cycle: inputs, attendance lock, gross pay, statutory deductions, net pay review, salary payment, statutory deposits, and payslips." xmlns="http://www.w3.org/2000/svg">
  <defs>
    <marker id="arw" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#a8a29e"/>
    </marker>
  </defs>
  <rect width="760" height="190" fill="#fafaf9" rx="12"/>
  <g font-family="ui-sans-serif, system-ui, sans-serif" text-anchor="middle">
    <g>
      <rect x="24" y="40" width="150" height="52" rx="8" fill="#ffffff" stroke="#d6d3d1"/>
      <text x="99" y="62" font-size="12" font-weight="700" fill="#17392d">1 · Inputs</text>
      <text x="99" y="79" font-size="10.5" fill="#79716b">Master &amp; salary data</text>
    </g>
    <g>
      <rect x="204" y="40" width="150" height="52" rx="8" fill="#ffffff" stroke="#d6d3d1"/>
      <text x="279" y="62" font-size="12" font-weight="700" fill="#17392d">2 · Lock</text>
      <text x="279" y="79" font-size="10.5" fill="#79716b">Attendance &amp; leave</text>
    </g>
    <g>
      <rect x="384" y="40" width="150" height="52" rx="8" fill="#ffffff" stroke="#d6d3d1"/>
      <text x="459" y="62" font-size="12" font-weight="700" fill="#17392d">3 · Calculate</text>
      <text x="459" y="79" font-size="10.5" fill="#79716b">Gross → deductions</text>
    </g>
    <g>
      <rect x="564" y="40" width="150" height="52" rx="8" fill="#36775f" stroke="#2f6a55"/>
      <text x="639" y="62" font-size="12" font-weight="700" fill="#ffffff">4 · Review</text>
      <text x="639" y="79" font-size="10.5" fill="#c8e3d8">Net pay approval</text>
    </g>
    <g>
      <rect x="204" y="122" width="150" height="46" rx="8" fill="#ffffff" stroke="#d6d3d1"/>
      <text x="279" y="141" font-size="12" font-weight="700" fill="#17392d">7 · Deposit</text>
      <text x="279" y="157" font-size="10.5" fill="#79716b">PF · ESI · PT · TDS</text>
    </g>
    <g>
      <rect x="384" y="122" width="150" height="46" rx="8" fill="#ffffff" stroke="#d6d3d1"/>
      <text x="459" y="141" font-size="12" font-weight="700" fill="#17392d">6 · Pay</text>
      <text x="459" y="157" font-size="10.5" fill="#79716b">Bank transfer</text>
    </g>
    <g>
      <rect x="24" y="122" width="150" height="46" rx="8" fill="#ffffff" stroke="#d6d3d1"/>
      <text x="99" y="141" font-size="12" font-weight="700" fill="#17392d">8 · Publish</text>
      <text x="99" y="157" font-size="10.5" fill="#79716b">Payslips &amp; returns</text>
    </g>
  </g>
  <g stroke="#a8a29e" stroke-width="1.5" fill="none" marker-end="url(#arw)">
    <path d="M 178 66 L 200 66"/>
    <path d="M 358 66 L 380 66"/>
    <path d="M 538 66 L 560 66"/>
    <path d="M 639 96 L 639 145 L 538 145"/>
    <path d="M 380 145 L 358 145"/>
    <path d="M 200 145 L 178 145"/>
  </g>
</svg>
<figcaption>The payroll month runs left to right along the top, then back along the bottom. Nothing below the review gate can start until it closes.</figcaption>
</figure>

## Step 1: Freeze your employee and salary master

Before any calculation, the underlying data has to be settled for the month:

- **New joiners** — date of joining, whether their first month is partial, PF and ESI applicability, bank details, PAN and UAN
- **Exits** — last working day, notice recovery, leave encashment, and whether a full-and-final settlement runs separately
- **Salary revisions** — the effective date matters more than the approval date. An increment approved on the 20th but effective from the 1st changes the whole month
- **Salary structures** — how CTC splits into Basic, HRA, and allowances, since Basic drives the PF calculation

This is where the most expensive errors originate, because everything downstream inherits them silently.

## Step 2: Lock attendance and leave

Payroll needs a closed attendance period. That means every leave request for the month is approved or rejected, not pending, and unapproved absence is converted into Loss of Pay.

The rule that catches teams out: **LOP is a per-day deduction, but the denominator is a policy decision.** Dividing monthly salary by calendar days, by fixed 30 days, or by working days produces three different numbers for the same absence. Pick one, write it into your leave policy, and apply it consistently — inconsistency here is what employees notice and escalate.

Once attendance is locked, it should not reopen. A correction that arrives afterwards belongs in next month's payroll as an arrear, not as a retroactive edit to a run you have already paid.

## Step 3: Calculate gross earnings

Gross pay is the sum of every earning before deductions:

- Basic salary
- House Rent Allowance
- Other fixed allowances — conveyance, special allowance, and similar
- Variable pay for the month — overtime, incentives, arrears

Gross is prorated for partial months and reduced by LOP days. It is also the figure that determines ESI eligibility, so getting it right has consequences beyond the payslip total.

## Step 4: Calculate statutory deductions

Four deductions apply to most Indian employers. Each has its own base, its own threshold, and its own rounding.

### Provident Fund

PF is generally calculated on Basic plus Dearness Allowance, at **12% from the employee and 12% from the employer**. A statutory wage ceiling of **₹15,000 per month** applies — many employers cap the contribution there, which puts the employee deduction at ₹1,800.

The employer's 12% is not a single bucket. It splits into the Employees' Pension Scheme at **8.33%** and the Provident Fund at the remainder. The pension portion is always computed on the capped wage regardless of whether you contribute on full Basic. Employers also pay administrative and EDLI insurance charges on top.

Two points that matter on the payslip: the employee's 12% is a deduction the employee sees, while the employer's 12% is a cost to the company that does not reduce take-home pay.

### Employees' State Insurance

ESI applies only where monthly gross is at or below **₹21,000**. Where it applies, the employee contributes **0.75%** and the employer **3.25%** of gross.

The mechanic worth knowing: ESI runs in fixed contribution periods, and an employee who crosses the threshold mid-period generally continues contributing until the end of that period rather than dropping out immediately. An increment does not switch ESI off the same month.

### Professional Tax

Professional Tax is levied by state, not centrally. Slabs, deduction frequency and even whether the tax exists at all vary — some states have no Professional Tax, and others deduct annually rather than monthly.

If you employ people in more than one state, you are running more than one Professional Tax rule, keyed to each employee's work location rather than your head office.

### TDS on salary

Tax Deducted at Source is fundamentally different from the other three. It is not a flat percentage of the month's pay — it is the employee's **projected annual tax liability**, spread across the remaining months of the financial year.

That projection depends on the regime the employee chose, their declared investments and exemptions, and any income they reported from a previous employer. When an employee submits a fresh declaration in December, the remaining months absorb the entire correction, which is why year-end TDS often jumps.

Collect regime elections and investment declarations at the start of the financial year, and ask for proofs before the final quarter.

## Step 5: Arrive at net pay and review

Net pay is gross earnings minus employee deductions. Before approving, run comparisons rather than reading rows:

| Check | What you are looking for |
|---|---|
| Month-on-month variance | Any employee whose net pay moved more than ~10% without a known reason |
| Zero or negative net pay | Usually excess recovery or a full-month LOP |
| New joiners and exits | Correct proration, and settlement handled |
| Threshold crossings | Employees who entered or left ESI applicability |
| Headcount and totals | Payroll headcount reconciles to the employee master |

The point of a review step is to catch exceptions, not to re-verify arithmetic. If your process requires recalculating numbers by hand to trust them, that is the thing to fix.

## Step 6: Pay salaries

Most employers pay via a bank upload file rather than individual transfers. Each bank expects its own format and column order, and a rejected file usually comes back with an unhelpful error, so the practical safeguards are: confirm the total in the file equals approved net payable, check that every active employee has valid account details before generating it, and keep the file tied to the specific payroll run that produced it.

## Step 7: Deposit statutory dues

Deductions become liabilities the moment they are withheld. Broad timing, which you should confirm against current notifications rather than memory:

| Dues | Generally due |
|---|---|
| Salary TDS | 7th of the following month; March is generally 30 April for non-government deductors |
| EPF contribution | Within 15 days of the close of the month |
| ESI contribution | Within 15 days of the end of the wage month |
| Professional Tax | Varies by state |

Late deposits attract interest and penalties, and unpaid TDS can be disallowed as an expense. Our [payroll compliance calendar](/resources/payroll-compliance-calendar) lays these out month by month with links to the official sources.

## Step 8: Publish payslips

A payslip should let an employee reconstruct their own number: earnings itemised, deductions itemised, LOP days shown, and year-to-date figures for the statutory components. Publishing through a self-service portal rather than email attachments also removes the recurring "can you resend my March payslip" request, which is a larger share of HR time than it should be.

Quarterly TDS returns and annual Form 16 issuance follow the same discipline — they are downstream of data you already produced, so they are only painful when the monthly records are inconsistent.

## The mistakes that cost the most

**Editing a paid payroll run.** Once salaries are disbursed and dues deposited, the run is a record. Corrections belong in the next month as arrears or recovery.

**Treating CTC as gross.** CTC includes employer PF, employer ESI and often gratuity provision. None of those are money the employee receives this month.

**Running Professional Tax on one state's rules.** The moment you hire outside your home state, this breaks quietly.

**Collecting tax declarations late.** A declaration that arrives in February cannot be spread across a year that has two months left.

**Keeping attendance, salary and deductions in separate files.** Every hand-off between spreadsheets is a place for numbers to diverge, and reconciliation cost grows faster than headcount.

## Making the sequence repeatable

The eight steps do not change with company size. What changes is how much of the sequence a person has to hold in their head. At twenty employees the spreadsheets are survivable. At a hundred, the reconciliation between them becomes the job.

Kula HR keeps these steps connected — attendance feeds the payroll run, salary structures drive statutory calculations, and the review gate sits before payment rather than after. If you want to see the numbers before committing to anything, the [free payroll calculators](/resources/payroll-calculators) show PF, ESI and take-home estimates with the assumptions visible, or you can read more about [PF, ESI and payroll compliance](/pf-esi-payroll-compliance) in the product.

---

*This guide is general information about payroll process, not legal or tax advice. Statutory rates, thresholds and due dates change through government notification, and the correct treatment depends on your establishment type, state and headcount. Confirm each obligation against the current official source before you deposit or file.*
