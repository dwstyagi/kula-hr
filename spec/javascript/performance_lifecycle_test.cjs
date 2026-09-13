const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const test = require("node:test")

function controller(name, globals = {}) {
  const source = fs.readFileSync(`app/javascript/controllers/${name}_controller.js`, "utf8")
    .replace(/^import .*\n/, "").replace("export default class", "globalThis.Subject = class")
  const context = vm.createContext({ Controller: class {}, console, ...globals })
  vm.runInContext(source, context)
  return new context.Subject()
}

test("upload events are removed on disconnect, including repeated reconnects", () => {
  const subject = controller("file_upload")
  subject.dropzoneTarget = new EventTarget()
  let calls = 0
  subject.onDragOver = () => calls++
  for (let i = 0; i < 5; i++) {
    subject.connect()
    subject.dropzoneTarget.dispatchEvent(new Event("dragover"))
    subject.disconnect()
    subject.dropzoneTarget.dispatchEvent(new Event("dragover"))
  }
  assert.equal(calls, 5)
})

test("public page releases window listeners and both observers", () => {
  const window = new EventTarget()
  window.scrollY = 0
  window.matchMedia = () => ({ matches: false })
  let disconnected = 0, scrollCalls = 0
  class Observer { observe() {} unobserve() {} disconnect() { disconnected++ } }
  window.IntersectionObserver = Observer
  const subject = controller("public_page", { window, IntersectionObserver: Observer })
  subject.element = {
    querySelector: selector => selector === "#site-header" ? { classList: { toggle: () => scrollCalls++ } } : null,
    querySelectorAll: () => []
  }
  for (let i = 0; i < 3; i++) {
    subject.connect()
    subject.disconnect()
  }
  window.dispatchEvent(new Event("scroll"))
  assert.equal(scrollCalls, 3)
  assert.equal(disconnected, 6)
})

test("chart loading after disconnect does not render into a removed page", async () => {
  let rendered = 0, destroyed = 0
  const window = { Chart: {}, Chartkick: { LineChart: class {
    constructor() { rendered++ }
    destroy() { destroyed++ }
  } } }
  const subject = controller("chart", { window, document: {} })
  subject.typeValue = "line"
  subject.dataValue = []
  subject.optionsValue = {}
  subject.element = {}
  const first = subject.connect()
  subject.disconnect()
  await first
  assert.equal(rendered, 0)
  await subject.connect()
  subject.disconnect()
  assert.equal(rendered, 1)
  assert.equal(destroyed, 1)
})

test("payroll guide disconnect removes keyboard handling and releases scrolling", () => {
  const document = new EventTarget()
  const classes = new Set()
  document.body = { classList: { add: x => classes.add(x), remove: x => classes.delete(x) } }
  const subject = controller("payroll_guide", { document })
  subject.dialogTarget = { classList: { remove() {} } }
  subject.render = () => {}
  let keys = 0
  subject.handleKeydown = () => keys++
  for (let i = 0; i < 3; i++) {
    subject.connect()
    subject.open()
    subject.disconnect()
  }
  document.dispatchEvent(new Event("keydown"))
  assert.equal(keys, 0)
  assert.equal(classes.size, 0)
})

test("task polling resumes after a hidden tab becomes visible and stops on disconnect", () => {
  const document = new EventTarget()
  document.hidden = true
  const timers = new Map()
  let next = 0, visits = 0
  const subject = controller("task_status", {
    document,
    setTimeout: callback => { const id = ++next; timers.set(id, callback); return id },
    clearTimeout: id => timers.delete(id),
    window: { location: { href: "/task" }, Turbo: { visit: () => visits++ } }
  })
  subject.connect()
  const tick = () => { const [id, callback] = timers.entries().next().value; timers.delete(id); callback() }
  tick()
  assert.equal(visits, 0)
  assert.equal(timers.size, 1)
  document.hidden = false
  document.dispatchEvent(new Event("visibilitychange"))
  tick()
  assert.equal(visits, 1)
  subject.disconnect()
  document.dispatchEvent(new Event("visibilitychange"))
  assert.equal(timers.size, 0)
})

test("off-cycle search ignores results that arrive after navigation", async () => {
  let resolveRows
  const rows = new Promise(resolve => { resolveRows = resolve })
  const subject = controller("off_cycle_form", {
    AbortController, URL,
    clearTimeout() {},
    window: { location: { origin: "https://example.com" } },
    fetch: async () => ({ ok: true, json: () => rows })
  })
  subject.rowTargets = []
  subject.connect()
  subject.hasUrlValue = true
  subject.urlValue = "/employees"
  subject.searchTarget = { value: "employee" }
  subject.element = { querySelector: () => assert.fail("Modified disconnected form") }
  const pending = subject.loadCandidates()
  await Promise.resolve()
  subject.disconnect()
  resolveRows([{id: 1, name: "Employee"}])
  await pending
})
