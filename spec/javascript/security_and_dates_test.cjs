const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const root = require('node:path').resolve(__dirname, '../..');
function controller(name, globals = {}) {
  const code = fs.readFileSync(`${root}/app/javascript/controllers/${name}_controller.js`, 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'globalThis.Subject = class');
  const context = vm.createContext({ Controller: class {}, console, ...globals });
  vm.runInContext(code, context);
  return new context.Subject();
}
test('notification text cannot insert HTML event handlers', () => {
  let toast;
  const document = {
    createElement() { return toast = { dataset: {}, style: {} }; },
    body: { appendChild() {} }
  };
  const subject = controller('notifications', { document, setTimeout() {} });
  subject.showToast({ title: 'New Leave Request', message: '<img src=x onerror="globalThis.reviewMarker=true"> applied for leave' });
  assert.ok(!toast.innerHTML.includes('<img src=x onerror='));
});
test('salary component names cannot insert HTML event handlers', () => {
  const subject = controller('ctc_calculator');
  const html = subject._renderBreakup({ earnings: [{ name: '<img src=x onerror="globalThis.reviewMarker=true">', monthly: 100, annual: 1200 }],
    deductions: [], employer_contributions: [], gross_monthly: 100, gross_annual: 1200,
    total_deductions_monthly: 0, net_monthly: 100, net_annual: 1200 });
  assert.ok(!html.includes('<img src=x onerror='));
});
test('a Monday date input counts as a working day in a western browser timezone', () => {
  const subject = controller('leave_calculator');
  subject.weekOffPatternValue = 'all_saturdays_sundays';
  subject.holidayDatesValue = [];
  assert.equal(subject.countBusinessDays(new Date('2026-10-19'), new Date('2026-10-19')), 1);
});
