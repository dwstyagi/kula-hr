class MarketingPagesController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  PAGES = {
    "payroll" => {
      slug: "payroll-software-india",
      title: "Payroll Software for Indian Companies | Kula HR",
      description: "Run Indian payroll with automated PF, ESI, Professional Tax, TDS, payslips, bank files and statutory reports. Start with one free payroll run.",
      eyebrow: "Indian payroll software",
      headline: "Close payroll without closing ten spreadsheets.",
      lede: "Kula HR brings attendance, salary structures, statutory deductions, payslips and bank files into one reviewable payroll run built for Indian teams.",
      badge: "One free payroll run · up to 25 employees",
      ledger_label: "March payroll · ready to review",
      ledger_rows: [
        [ "Employees", "42", "Included" ],
        [ "Gross payroll", "₹10,84,260", "Calculated" ],
        [ "PF · ESI · PT · TDS", "₹1,76,430", "Checked" ],
        [ "Net payable", "₹9,07,830", "Ready" ]
      ],
      problem_heading: "One payroll run, from attendance lock to bank upload",
      problem_body: "Payroll errors usually appear at the hand-offs: attendance in one file, salary revisions in another, deductions in a third, and bank totals calculated again. Kula HR keeps those inputs connected so HR can review exceptions instead of rebuilding the same calculation every month.",
      outcomes: [
        [ "Statutory calculations", "Calculate employee and employer PF, ESI eligibility, state-based Professional Tax and projected TDS inside the payroll run." ],
        [ "Review before release", "See gross pay, deductions, LOP and net pay employee by employee before approving or marking payroll paid." ],
        [ "Outputs that are ready to use", "Generate PDF payslips, HDFC/ICICI/SBI bank files, PF ECR, ESI statements and payroll reports from approved data." ]
      ],
      sections: [
        {
          kicker: "Prepare",
          title: "Bring monthly inputs together before calculating pay",
          body: "Lock attendance, apply approved leave, account for joiners and exits, and use effective-dated salary revisions. Payroll readiness checks make missing inputs visible before processing begins.",
          bullets: [ "Attendance and LOP flow into payroll", "Effective salary history prevents retroactive overwrites", "Readiness checks flag incomplete employee setup" ]
        },
        {
          kicker: "Process",
          title: "Apply Indian payroll rules consistently",
          body: "Kula HR calculates earnings and deductions for every participant in the run, including proration for paid days and statutory eligibility. HR retains a clear line-item view instead of a hidden total.",
          bullets: [ "CTC-based Basic, HRA and allowance breakup", "PF, ESI, PT and TDS line items", "On-cycle and off-cycle payroll support" ]
        },
        {
          kicker: "Pay & file",
          title: "Move from approved payroll to actual payment",
          body: "Once approved, download a bank-ready salary file and publish payslips to the employee portal. Filing reports use the same payroll data, so totals do not need to be reconciled again.",
          bullets: [ "Bank-specific and generic transfer files", "Employee payslip history and YTD totals", "Filing-ready statutory exports" ]
        }
      ],
      steps: [
        [ "Import your team", "Add employees individually or validate a CSV/Excel import before saving." ],
        [ "Configure salary and rules", "Set salary structures, payroll settings, holidays and work locations." ],
        [ "Review and approve", "Process payroll, inspect exceptions and approve the final totals." ],
        [ "Pay and publish", "Download the bank file, mark the run paid and release payslips." ]
      ],
      faqs: [
        [ "Which Indian payroll deductions does Kula HR handle?", "Kula HR calculates PF/EPF, ESI, state-based Professional Tax and TDS under the selected tax regime, based on the payroll settings and employee data you configure." ],
        [ "Can attendance and leave affect payroll automatically?", "Yes. Locked attendance summaries, approved leave and loss-of-pay days feed into payroll proration, reducing duplicate data entry." ],
        [ "Which bank files can I generate?", "Kula HR supports HDFC, ICICI and SBI salary-transfer formats plus a generic CSV for other corporate-banking workflows." ],
        [ "Can I test payroll before paying?", "Yes. The free trial includes one complete payroll run for up to 25 employees, with no credit card required." ]
      ]
    },
    "hrms" => {
      slug: "hrms-software-for-small-business",
      title: "HRMS Software for Small Businesses in India | Kula HR",
      description: "Manage employees, leave, attendance, salary structures, payroll and self-service in one HRMS built for growing Indian businesses.",
      eyebrow: "HRMS for growing Indian teams",
      headline: "An HR system small teams can operate without a systems team.",
      lede: "Give HR one place to manage employee records, attendance, leave, salary changes, payroll and statutory outputs—without stitching together separate tools.",
      badge: "All core modules included · no setup fee",
      ledger_label: "People operations · this month",
      ledger_rows: [
        [ "Active employees", "42", "Current" ],
        [ "Pending leave", "3", "To review" ],
        [ "Attendance", "March", "Locked" ],
        [ "Payroll", "March", "Ready" ]
      ],
      problem_heading: "Keep the employee lifecycle connected",
      problem_body: "Small HR teams feel fragmentation first. A new joiner added to one sheet must be recreated in attendance, payroll and payslip records. Kula HR keeps one employee record connected to every recurring HR workflow.",
      outcomes: [
        [ "One employee record", "Maintain personal, employment, salary, bank and statutory information with company-level access controls." ],
        [ "Operational workflows", "Handle onboarding, leave approvals, attendance summaries, announcements and payroll without moving data between products." ],
        [ "Employee self-service", "Let employees retrieve payslips, request leave, update profiles and submit tax declarations from their own portal." ]
      ],
      sections: [
        {
          kicker: "People data",
          title: "Build a dependable source of employee information",
          body: "Create employees one at a time or import them in bulk with validation. Organise the team by department, designation, work location and employment status.",
          bullets: [ "Validated CSV and Excel imports", "Departments, designations and work locations", "Joiner, active and exited employee states" ]
        },
        {
          kicker: "Workflows",
          title: "Move routine HR requests out of inboxes",
          body: "Employees submit leave and tax declarations in the portal while managers and HR work from a shared approval trail. Announcements keep company updates visible without another chat channel.",
          bullets: [ "Leave and comp-off approvals", "Company holidays and team calendar", "Announcements with read tracking" ]
        },
        {
          kicker: "Payroll connection",
          title: "Use HR records directly in monthly payroll",
          body: "Salary revisions, attendance, leave and statutory details remain attached to the employee record. Payroll uses those inputs directly and publishes results back to the employee portal.",
          bullets: [ "Effective-dated salary history", "Attendance-driven LOP", "Payslip and YTD history" ]
        }
      ],
      steps: [
        [ "Create your company", "Choose the company subdomain and state used for payroll defaults." ],
        [ "Bring in employees", "Import your current employee list and resolve validation errors before saving." ],
        [ "Set policies", "Configure leave types, holidays, salary structures and statutory settings." ],
        [ "Run monthly work", "Approve requests, lock attendance and process payroll in the same system." ]
      ],
      faqs: [
        [ "Is Kula HR suitable for a company without a dedicated HR team?", "Yes. The workflows are designed to be operated by founders, finance teams or a small HR function, with guided setup and sensible Indian payroll defaults." ],
        [ "Can employees access the HRMS themselves?", "Every employee can use a role-based self-service portal for payslips, leave, tax declarations, announcements and profile details." ],
        [ "Can we import existing employee data?", "Yes. Use the CSV or Excel template, preview validation errors, and import valid employee records in bulk." ],
        [ "Do modules cost extra?", "No. The paid plan includes the HR, payroll, compliance, reporting and employee-portal features listed on the pricing page." ]
      ]
    },
    "leave" => {
      slug: "leave-management-software",
      title: "Leave Management Software for Indian Teams | Kula HR",
      description: "Configure leave policies, balances, approvals, holidays, comp-off and payroll-linked LOP with Kula HR leave management software.",
      eyebrow: "Leave management software",
      headline: "Leave balances everyone can understand before they apply.",
      lede: "Replace message-based leave requests with visible balances, approval trails, team calendars and payroll-linked loss-of-pay calculations.",
      badge: "Employee requests · manager approvals · payroll connection",
      ledger_label: "Leave desk · current balance",
      ledger_rows: [
        [ "Casual leave", "5.0 days", "Available" ],
        [ "Sick leave", "3.5 days", "Available" ],
        [ "Earned leave", "8.0 days", "Available" ],
        [ "Pending requests", "1", "In review" ]
      ],
      problem_heading: "Make policy, approval and payroll agree",
      problem_body: "A leave request is not complete when a manager replies “approved.” The balance must update, the team needs visibility, attendance must reflect the absence and payroll must know whether any days are unpaid.",
      outcomes: [
        [ "Configurable policies", "Define leave types, paid or unpaid behaviour, annual entitlement and active status for your company." ],
        [ "Clear approvals", "Route employee requests to the appropriate approver with pending, approved, rejected and cancelled states." ],
        [ "Payroll-aware balances", "Approved leave and LOP days feed attendance summaries used by the monthly payroll run." ]
      ],
      sections: [
        {
          kicker: "For employees",
          title: "Show the balance before the request",
          body: "Employees can see available leave, choose dates, add a reason and track the decision in their portal. They no longer need HR to answer routine balance questions.",
          bullets: [ "Current balances by leave type", "Request status and cancellation", "Personal leave history" ]
        },
        {
          kicker: "For managers",
          title: "Approve with team context",
          body: "Managers review requests for their team and use the shared calendar to spot overlapping absences. HR retains company-wide control and a consistent record of each decision.",
          bullets: [ "Manager approval queues", "Team leave calendar", "Bulk approval for HR workflows" ]
        },
        {
          kicker: "For payroll",
          title: "Carry unpaid days into the correct month",
          body: "Attendance summaries combine leave, holidays and working days. When LOP applies, payroll prorates eligible earnings from the locked monthly summary.",
          bullets: [ "Attendance and leave reconciliation", "Month-level lock and unlock", "LOP proration in payroll" ]
        }
      ],
      steps: [
        [ "Define leave types", "Set names, codes, entitlement and whether each leave type is paid." ],
        [ "Assign balances", "Credit opening or accrued balances for eligible employees." ],
        [ "Approve requests", "Managers or HR review requests with team-calendar context." ],
        [ "Close the month", "Generate attendance summaries and carry LOP into payroll." ]
      ],
      faqs: [
        [ "Can we create our own leave types?", "Yes. Configure company-specific leave types alongside common policies such as casual, sick and earned leave." ],
        [ "Does Kula HR support comp-off?", "Yes. Employees can request comp-off credit and use approved balances through the leave workflow." ],
        [ "Can managers approve only their own team’s leave?", "Yes. Team views and approval access follow role and reporting responsibilities configured for the employee." ],
        [ "How does unpaid leave affect payroll?", "Approved leave and attendance summaries determine LOP days, which are then used to prorate payroll for the applicable month." ]
      ]
    },
    "attendance" => {
      slug: "attendance-management-software",
      title: "Attendance Management Software for India | Kula HR",
      description: "Prepare monthly attendance, working days, holidays and LOP for payroll with Kula HR attendance management software for Indian teams.",
      eyebrow: "Payroll-ready attendance",
      headline: "Turn the attendance month into a number payroll can trust.",
      lede: "Kula HR combines working days, holidays, approved leave, joiners, exits and manual adjustments into a lockable monthly attendance summary.",
      badge: "Generate · review · adjust · lock",
      ledger_label: "March attendance · locked",
      ledger_rows: [
        [ "Working days", "26", "Calendar" ],
        [ "Paid days", "25", "Confirmed" ],
        [ "LOP days", "1", "Payroll" ],
        [ "Status", "Locked", "Final" ]
      ],
      problem_heading: "Close attendance once, then use it everywhere",
      problem_body: "Payroll should not discover attendance changes after calculation. Kula HR creates a month-level summary that HR can review, adjust and lock before payroll begins, leaving a clear source for paid days and LOP.",
      outcomes: [
        [ "Calendar-aware working days", "Calculate working days from company week-offs, holidays and employee work locations." ],
        [ "Reviewable employee summaries", "See present, absent, leave, paid and LOP days for every employee before locking the period." ],
        [ "Direct payroll input", "Use the locked summary for salary proration without exporting attendance into a second calculation sheet." ]
      ],
      sections: [
        {
          kicker: "Generate",
          title: "Build the month from company and employee calendars",
          body: "Kula HR accounts for holidays, week-off rules, joining dates and exit dates when generating employee attendance summaries for the selected payroll month.",
          bullets: [ "Location-specific holiday calendars", "Joiner and exit-date handling", "Configurable week-off settings" ]
        },
        {
          kicker: "Review",
          title: "Correct exceptions before they become payroll errors",
          body: "HR can review summaries on screen, edit permitted values or upload the attendance template. Validation makes discrepancies visible before the month is finalized.",
          bullets: [ "On-screen adjustments", "Template upload for existing attendance data", "Employee-level day breakdown" ]
        },
        {
          kicker: "Lock",
          title: "Give payroll a stable monthly input",
          body: "Locking prevents accidental changes while payroll is processed. If a genuine correction is needed, authorised users can reopen the month, update it and rerun the dependent calculation.",
          bullets: [ "Explicit month locking", "Controlled unlock workflow", "LOP and paid-day payroll proration" ]
        }
      ],
      steps: [
        [ "Set the calendar", "Configure week-offs, holidays and work locations." ],
        [ "Generate summaries", "Create the monthly record for every eligible employee." ],
        [ "Resolve exceptions", "Review leave, absences, joiners, exits and uploaded adjustments." ],
        [ "Lock for payroll", "Finalize paid and LOP days before processing salaries." ]
      ],
      faqs: [
        [ "Does Kula HR include biometric attendance?", "Kula HR currently focuses on payroll-ready monthly summaries. Existing attendance data can be entered on screen or uploaded using the provided template." ],
        [ "Can holidays vary by office location?", "Yes. Work locations can use location-specific holiday calendars when calculating monthly working days." ],
        [ "How are mid-month joiners handled?", "The working-days calculation considers employment dates so joiners and exiting employees are paid only for eligible days." ],
        [ "Can attendance change after it is locked?", "Authorised HR users can unlock a month when a legitimate correction is required, then lock it again before payroll processing." ]
      ]
    },
    "compliance" => {
      slug: "pf-esi-payroll-compliance",
      title: "PF & ESI Payroll Compliance Software | Kula HR",
      description: "Automate PF, ESI, Professional Tax and TDS calculations and generate filing-ready payroll reports with Kula HR.",
      eyebrow: "Indian statutory payroll",
      headline: "Calculate statutory deductions where payroll is calculated.",
      lede: "Apply PF, ESI, state Professional Tax and TDS rules to the same employee and payroll data used for net pay, then generate the reports needed for filing.",
      badge: "PF · ESI · Professional Tax · TDS",
      ledger_label: "Statutory checks · payroll run",
      ledger_rows: [
        [ "PF / EPF", "ECR", "Generated" ],
        [ "ESI", "Eligibility", "Checked" ],
        [ "Professional Tax", "State slab", "Applied" ],
        [ "TDS", "FY projection", "Updated" ]
      ],
      problem_heading: "Use one set of payroll totals for payment and filing",
      problem_body: "Compliance work becomes fragile when contribution reports are rebuilt after payroll is approved. Kula HR calculates statutory line items during payroll and produces reports from those same approved payslips.",
      outcomes: [
        [ "PF and ESI calculations", "Apply configured contribution rates, eligibility thresholds and employer contributions to each payroll participant." ],
        [ "State-aware Professional Tax", "Use the employee or company state configuration to apply supported monthly PT slabs, including state-specific variations." ],
        [ "Projected TDS", "Use declared tax regime and investment details to project annual tax and calculate the monthly deduction." ]
      ],
      sections: [
        {
          kicker: "Provident Fund",
          title: "Keep PF wages and contributions attached to the payslip",
          body: "Employee and employer PF amounts are calculated as payroll line items. The monthly PF report and ECR export use those stored results instead of recalculating contributions separately.",
          bullets: [ "Employee and employer PF", "EPF and EPS reporting fields", "Pipe-delimited ECR export" ]
        },
        {
          kicker: "ESI & PT",
          title: "Apply eligibility and state rules during the run",
          body: "ESI eligibility is checked against configured wages and rates. Professional Tax uses supported state slabs, keeping both deductions visible during payroll review.",
          bullets: [ "Employee and employer ESI shares", "Eligibility-based inclusion", "State-specific PT calculation" ]
        },
        {
          kicker: "Income tax",
          title: "Connect employee declarations to monthly TDS",
          body: "Employees select the applicable regime and submit investment details in self-service. Payroll uses the projected annual liability to calculate the monthly TDS amount.",
          bullets: [ "Old and New Regime declarations", "Investment declaration workflow", "YTD earnings and deduction reporting" ]
        }
      ],
      steps: [
        [ "Configure company rules", "Review rates, thresholds, state and statutory settings." ],
        [ "Complete employee details", "Record PAN, UAN, eligibility flags and tax declarations." ],
        [ "Process and review", "Inspect statutory line items alongside earnings and net pay." ],
        [ "Export reports", "Download PF ECR, ESI, PT and YTD reports from approved payroll." ]
      ],
      faqs: [
        [ "Does Kula HR file statutory returns automatically?", "Kula HR calculates contributions and generates filing-ready reports and export files. Your organisation remains responsible for verifying and submitting them through the relevant government portals." ],
        [ "Are employer PF and ESI contributions supported?", "Yes. Payroll can calculate and report both employee and employer contribution amounts according to your configured settings." ],
        [ "Which Professional Tax states are supported?", "The product currently advertises multi-state PT support. Confirm your required state during setup so the applicable slab configuration can be verified." ],
        [ "Can employees submit tax declarations online?", "Yes. Employees can choose a tax regime and submit declaration details from their self-service portal for use in TDS projection." ]
      ]
    },
    "employee_portal" => {
      slug: "employee-self-service-portal",
      title: "Employee Self-Service Portal Software | Kula HR",
      description: "Give employees secure self-service access to payslips, leave, tax declarations, announcements and profile details with Kula HR.",
      eyebrow: "Employee self-service",
      headline: "Give employees answers without turning HR into a help desk.",
      lede: "Every employee gets a secure portal for payslips, leave, tax declarations, announcements and profile details—connected to the same HR and payroll records.",
      badge: "Included with every Kula HR plan",
      ledger_label: "My portal · March",
      ledger_rows: [
        [ "Latest payslip", "March", "Available" ],
        [ "Leave balance", "16.5 days", "Current" ],
        [ "Tax declaration", "New Regime", "Submitted" ],
        [ "Announcements", "2 unread", "New" ]
      ],
      problem_heading: "Move routine employee requests into a secure personal workspace",
      problem_body: "Employees should not need to email HR for a payslip or ask for the same leave balance twice. Self-service gives each person direct access while role-based controls keep company and employee records separated.",
      outcomes: [
        [ "Payslips on demand", "View and download approved payslips with monthly history and year-to-date earnings summaries." ],
        [ "Leave without email", "Check balances, submit requests, track approvals and cancel eligible requests from one place." ],
        [ "Tax declarations online", "Choose the applicable tax regime and submit investment details for payroll TDS calculations." ]
      ],
      sections: [
        {
          kicker: "Pay",
          title: "Keep every approved payslip in one history",
          body: "Once payroll is marked paid, the employee can open the detailed payslip or download its PDF. Previous months and YTD totals remain available without an HR request.",
          bullets: [ "PDF payslip downloads", "Twelve-month history", "YTD gross, deductions and net pay" ]
        },
        {
          kicker: "Time off",
          title: "Make leave balances and request status visible",
          body: "Employees see balances before applying and can follow each request through approval. Managers receive their own team views for approvals and calendar planning.",
          bullets: [ "Balance by leave type", "Request and cancellation status", "Manager team calendar" ]
        },
        {
          kicker: "Employee data",
          title: "Collect updates at the source",
          body: "Employees can review their personal and bank details, submit tax information and read company announcements. HR keeps control over fields and workflows that require approval.",
          bullets: [ "Profile and bank information", "Tax declaration submissions", "Announcements with unread indicators" ]
        }
      ],
      steps: [
        [ "Invite the employee", "Send an activation link tied to the company and employee record." ],
        [ "Employee activates access", "Create secure credentials for the company subdomain." ],
        [ "HR publishes records", "Approved payroll and announcements become available automatically." ],
        [ "Employee self-serves", "Retrieve documents and submit requests without duplicating records." ]
      ],
      faqs: [
        [ "Does employee self-service cost extra?", "No. The employee portal is included with the trial and paid plan described on the Kula HR pricing page." ],
        [ "Can employees see another employee’s information?", "No. Portal access is scoped to the signed-in employee, while managers receive only the team views their role permits." ],
        [ "When does a payslip become visible?", "Employees see payslips after the payroll run reaches an approved or paid state, not while HR is still preparing a draft." ],
        [ "Can employees update bank details?", "Employees can maintain permitted profile information in the portal. Company policy should determine which changes HR verifies before the next payroll." ]
      ]
    },
    "pricing" => {
      slug: "pricing",
      title: "Kula HR Pricing — ₹99 per Employee per Month",
      description: "Start with one free payroll run for up to 25 employees, then use every Kula HR feature for ₹99 per employee per month.",
      eyebrow: "Simple HRMS pricing",
      headline: "One price for the workflow, not a menu of locked modules.",
      lede: "Run one complete payroll free for up to 25 employees. Continue for ₹99 per employee each month with payroll, HR, compliance, reports and self-service included.",
      badge: "No credit card · no setup fee · cancel anytime",
      ledger_label: "Example · 25 employees",
      ledger_rows: [
        [ "Employees", "25", "Active" ],
        [ "Price per employee", "₹99", "Monthly" ],
        [ "Feature add-ons", "₹0", "Included" ],
        [ "Monthly total", "₹2,475", "Before taxes" ]
      ],
      problem_heading: "Know the software cost before adding your team",
      problem_body: "Kula HR does not separate payroll, leave, attendance, compliance reports and the employee portal into different feature tiers. The recurring price scales with active employee count, while the first payroll run lets you validate the workflow before paying.",
      outcomes: [
        [ "Free first payroll", "Process one complete payroll run for up to 25 employees without entering a card." ],
        [ "₹99 per employee monthly", "Continue with unlimited payroll runs and employees on a clear per-employee price." ],
        [ "Core features included", "Use payroll, HR records, leave, attendance, bank files, reports and employee self-service without module add-ons." ]
      ],
      sections: [
        {
          kicker: "Trial",
          title: "Test the real payroll workflow, not a limited product tour",
          body: "The trial includes employee import, salary setup, attendance, statutory calculations, payslip generation, reports and the employee portal for one payroll run.",
          bullets: [ "Up to 25 employees", "One complete payroll run", "No credit card required" ]
        },
        {
          kicker: "Paid plan",
          title: "Continue with every core module available",
          body: "After the trial, pricing is ₹99 per employee per month. There is no separate charge listed for bank formats, statutory reports, leave, attendance or self-service.",
          bullets: [ "Unlimited payroll runs", "Unlimited employee count", "Priority email support" ]
        },
        {
          kicker: "What is included",
          title: "Use one subscription from onboarding to filing reports",
          body: "The plan covers employee management, salary structures, payroll processing, leave, attendance, payslips, bank files, statutory reports and employee access.",
          bullets: [ "HDFC, ICICI, SBI and generic bank files", "PF ECR, ESI, PT and YTD reports", "Employee payslip and leave portal" ]
        }
      ],
      steps: [
        [ "Create an account", "No card is required to create the company workspace." ],
        [ "Add up to 25 employees", "Import or enter the team used for the trial payroll." ],
        [ "Run payroll free", "Validate calculations, outputs and employee access." ],
        [ "Upgrade when ready", "Continue at ₹99 per active employee per month." ]
      ],
      faqs: [
        [ "Is a credit card required for the trial?", "No. You can create the account and run the included payroll without providing a credit card." ],
        [ "Are payroll and HR features priced separately?", "No. The currently advertised paid plan includes the listed payroll, HR, compliance, reporting and employee-portal features." ],
        [ "What happens after the free payroll run?", "You can review the completed run and choose whether to upgrade. Continuing payroll processing requires the paid subscription." ],
        [ "Are taxes included in ₹99?", "The displayed example is before applicable taxes. Confirm the final billed amount and tax treatment during subscription setup." ]
      ]
    }
  }.freeze

  def show
    @page = PAGES.fetch(params[:page])
  end
end
