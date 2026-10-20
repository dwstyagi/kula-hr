const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
function calculator({ from, to, duration = 'full_day', holidays = [], balance = 2, unlimited = false }) {
  const source = fs.readFileSync(path.resolve(__dirname, '../../app/javascript/controllers/leave_calculator_controller.js'), 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'globalThis.Subject = class');
  const context = vm.createContext({ Controller: class {} });
  vm.runInContext(source, context);
  const subject = new context.Subject();
  Object.assign(subject, { fromDateTarget: { value: from }, toDateTarget: { value: to },
    durationTarget: { value: duration }, hasDurationTarget: true, daysTarget: {}, balanceTarget: {},
    balancesValue: balance === null ? {} : { '1': balance }, holidayDatesValue: holidays,
    weekOffPatternValue: 'all_saturdays_sundays' });
  const state = { hidden: true };
  subject.warningTarget = { classList: { add() { state.hidden = true; }, remove() { state.hidden = false; }, toggle(_, hidden) { state.hidden = hidden; } } };
  subject.element = { querySelector() { return { value: '1', selectedOptions: [{ dataset: { unlimited: String(unlimited) } }] }; } };
  subject.recalculate();
  return { subject, state };
}
test('half-day preview requests 0.5 and flags insufficient fractional balance', () => {
  const { subject, state } = calculator({ from: '2026-10-22', to: '2026-10-22', duration: 'morning', balance: 0.25 });
  assert.equal(subject.daysTarget.textContent, '0.5 days');
  assert.equal(state.hidden, false);
});
test('non-working selection shows zero, including a holiday half-day', () => {
  const { subject } = calculator({ from: '2026-10-22', to: '2026-10-22', duration: 'afternoon', holidays: ['2026-10-22'] });
  assert.equal(subject.daysTarget.textContent, '0 days');
});
test('multi-date half-day preview explains the single-date rule', () => {
  const { subject } = calculator({ from: '2026-10-22', to: '2026-10-23', duration: 'afternoon' });
  assert.equal(subject.daysTarget.textContent, 'Half days require one date');
});
test('missing paid balance is not presented as unlimited', () => {
  const { subject, state } = calculator({ from: '2026-10-22', to: '2026-10-22', balance: null });
  assert.match(subject.balanceTarget.textContent, /No balance/);
  assert.equal(state.hidden, false);
});
test('unpaid leave is explicitly shown as unlimited', () => {
  const { subject, state } = calculator({ from: '2026-10-22', to: '2026-10-22', balance: null, unlimited: true });
  assert.equal(subject.balanceTarget.textContent, 'Unlimited (unpaid leave)');
  assert.equal(state.hidden, true);
});
