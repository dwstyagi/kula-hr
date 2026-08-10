import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "pfBasic", "pfDa", "pfFull", "pfBase", "pfEmployee", "pfEmployer", "pfEps", "pfEpf",
    "esiGross", "esiStatus", "esiEmployee", "esiEmployer", "esiTotal",
    "ctcAnnual", "ctcBasicPercent", "ctcHraPercent", "ctcPt", "ctcTds", "ctcFullPf",
    "ctcMonthly", "ctcBasic", "ctcHra", "ctcSpecial", "ctcEmployerPf", "ctcEmployerEsi",
    "ctcEmployeePf", "ctcEmployeeEsi", "ctcDeductions", "ctcNet"
  ]

  connect() {
    this.calculateAll()
  }

  calculateAll() {
    this.calculatePf()
    this.calculateEsi()
    this.calculateCtc()
  }

  calculatePf() {
    const wage = this.number(this.pfBasicTarget) + this.number(this.pfDaTarget)
    const base = this.pfFullTarget.checked ? wage : Math.min(wage, 15000)
    const employee = Math.round(base * 0.12)
    const employer = Math.round(base * 0.12)
    const eps = Math.min(employer, Math.round(Math.min(base, 15000) * 0.0833))

    this.write(this.pfBaseTarget, base)
    this.write(this.pfEmployeeTarget, employee)
    this.write(this.pfEmployerTarget, employer)
    this.write(this.pfEpsTarget, eps)
    this.write(this.pfEpfTarget, employer - eps)
  }

  calculateEsi() {
    const gross = this.number(this.esiGrossTarget)
    const eligible = gross > 0 && gross <= 21000
    const employee = eligible ? Math.ceil(gross * 0.0075) : 0
    const employer = eligible ? Math.ceil(gross * 0.0325) : 0

    this.esiStatusTarget.textContent = eligible ? "Within ₹21,000 wage ceiling" : "Outside the standard wage ceiling"
    this.esiStatusTarget.className = eligible
      ? "mt-2 text-xs font-semibold text-kula-700"
      : "mt-2 text-xs font-semibold text-marigold-800"
    this.write(this.esiEmployeeTarget, employee)
    this.write(this.esiEmployerTarget, employer)
    this.write(this.esiTotalTarget, employee + employer)
  }

  calculateCtc() {
    const monthlyCtc = this.number(this.ctcAnnualTarget) / 12
    const basic = monthlyCtc * (this.number(this.ctcBasicPercentTarget, 40) / 100)
    const employerPfBase = this.ctcFullPfTarget.checked ? basic : Math.min(basic, 15000)
    const employerPf = Math.round(employerPfBase * 0.12)
    const beforeEsi = Math.max(monthlyCtc - employerPf, 0)
    const employerEsi = beforeEsi > 0 && beforeEsi <= 21000 ? Math.ceil(beforeEsi * 0.0325) : 0
    const gross = Math.max(monthlyCtc - employerPf - employerEsi, 0)
    const hra = Math.min(basic * (this.number(this.ctcHraPercentTarget, 50) / 100), Math.max(gross - basic, 0))
    const special = Math.max(gross - basic - hra, 0)
    const employeePf = Math.round(employerPfBase * 0.12)
    const employeeEsi = gross > 0 && gross <= 21000 ? Math.ceil(gross * 0.0075) : 0
    const deductions = employeePf + employeeEsi + this.number(this.ctcPtTarget) + this.number(this.ctcTdsTarget)
    const net = Math.max(gross - deductions, 0)

    this.write(this.ctcMonthlyTarget, monthlyCtc)
    this.write(this.ctcBasicTarget, basic)
    this.write(this.ctcHraTarget, hra)
    this.write(this.ctcSpecialTarget, special)
    this.write(this.ctcEmployerPfTarget, employerPf)
    this.write(this.ctcEmployerEsiTarget, employerEsi)
    this.write(this.ctcEmployeePfTarget, employeePf)
    this.write(this.ctcEmployeeEsiTarget, employeeEsi)
    this.write(this.ctcDeductionsTarget, deductions)
    this.write(this.ctcNetTarget, net)
  }

  number(target, fallback = 0) {
    const value = Number.parseFloat(target.value)
    return Number.isFinite(value) && value >= 0 ? value : fallback
  }

  write(target, value) {
    target.textContent = new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0
    }).format(value)
  }
}
