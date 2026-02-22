import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["structureSelect", "ctcInput", "breakup"]
  static values = { url: String }

  connect() {
    this._debounceTimer = null
  }

  calculate() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._fetchBreakup(), 400)
  }

  async _fetchBreakup() {
    const structureId = this.structureSelectTarget.value
    const ctc = this.ctcInputTarget.value

    if (!structureId || !ctc || parseFloat(ctc) < 100000) {
      this.breakupTarget.innerHTML = ""
      return
    }

    try {
      const response = await fetch(
        `${this.urlValue}?salary_structure_id=${structureId}&annual_ctc=${ctc}`,
        { headers: { "Accept": "application/json" } }
      )

      if (!response.ok) {
        this.breakupTarget.innerHTML = ""
        return
      }

      const data = await response.json()
      this.breakupTarget.innerHTML = this._renderBreakup(data)
    } catch {
      this.breakupTarget.innerHTML = ""
    }
  }

  _renderBreakup(data) {
    const fmt = (n) => new Intl.NumberFormat("en-IN", { maximumFractionDigits: 2 }).format(n)

    let html = `<div class="space-y-4 mt-6">`

    // Earnings
    html += `<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div class="px-4 py-2 bg-green-50 border-b border-green-100">
        <h4 class="text-sm font-semibold text-green-800">Earnings</h4>
      </div>
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500">Component</th>
            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Monthly</th>
            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Annual</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">`

    data.earnings.forEach(e => {
      html += `<tr>
        <td class="px-4 py-2 text-sm text-gray-900">${e.name}</td>
        <td class="px-4 py-2 text-sm text-gray-900 text-right font-mono">${fmt(e.monthly)}</td>
        <td class="px-4 py-2 text-sm text-gray-500 text-right font-mono">${fmt(e.annual)}</td>
      </tr>`
    })

    html += `<tr class="bg-green-50 font-semibold">
        <td class="px-4 py-2 text-sm text-green-800">Gross Salary</td>
        <td class="px-4 py-2 text-sm text-green-800 text-right font-mono">${fmt(data.gross_monthly)}</td>
        <td class="px-4 py-2 text-sm text-green-700 text-right font-mono">${fmt(data.gross_annual)}</td>
      </tr>
      </tbody></table></div>`

    // Deductions
    html += `<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div class="px-4 py-2 bg-red-50 border-b border-red-100">
        <h4 class="text-sm font-semibold text-red-800">Deductions</h4>
      </div>
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500">Component</th>
            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Monthly</th>
            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Annual</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">`

    data.deductions.forEach(d => {
      html += `<tr>
        <td class="px-4 py-2 text-sm text-gray-900">${d.name}</td>
        <td class="px-4 py-2 text-sm text-gray-900 text-right font-mono">${fmt(d.monthly)}</td>
        <td class="px-4 py-2 text-sm text-gray-500 text-right font-mono">${fmt(d.annual)}</td>
      </tr>`
    })

    html += `<tr class="bg-red-50 font-semibold">
        <td class="px-4 py-2 text-sm text-red-800">Total Deductions</td>
        <td class="px-4 py-2 text-sm text-red-800 text-right font-mono">${fmt(data.total_deductions_monthly)}</td>
        <td class="px-4 py-2 text-sm text-red-700 text-right font-mono">${fmt(data.total_deductions_monthly * 12)}</td>
      </tr>
      </tbody></table></div>`

    // Employer Contributions
    html += `<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div class="px-4 py-2 bg-blue-50 border-b border-blue-100">
        <h4 class="text-sm font-semibold text-blue-800">Employer Contributions</h4>
      </div>
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500">Component</th>
            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Monthly</th>
            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Annual</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">`

    data.employer_contributions.forEach(c => {
      html += `<tr>
        <td class="px-4 py-2 text-sm text-gray-900">${c.name}</td>
        <td class="px-4 py-2 text-sm text-gray-900 text-right font-mono">${fmt(c.monthly)}</td>
        <td class="px-4 py-2 text-sm text-gray-500 text-right font-mono">${fmt(c.annual)}</td>
      </tr>`
    })

    html += `</tbody></table></div>`

    // Net Summary
    html += `<div class="bg-gray-50 rounded-lg border border-gray-200 p-4">
      <div class="grid grid-cols-2 gap-4">
        <div>
          <p class="text-xs font-medium text-gray-500 uppercase">Net Take-Home (Monthly)</p>
          <p class="text-xl font-bold text-gray-900 font-mono mt-1">${fmt(data.net_monthly)}</p>
        </div>
        <div>
          <p class="text-xs font-medium text-gray-500 uppercase">Net Take-Home (Annual)</p>
          <p class="text-xl font-bold text-gray-900 font-mono mt-1">${fmt(data.net_annual)}</p>
        </div>
      </div>
    </div>`

    html += `</div>`
    return html
  }
}
