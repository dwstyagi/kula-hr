import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

const ICONS = {
  info:    { bg: "bg-blue-100",  text: "text-blue-600",  path: "M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" },
  success: { bg: "bg-green-100", text: "text-green-600", path: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" },
  error:   { bg: "bg-red-100",   text: "text-red-600",   path: "M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" }
}

export default class extends Controller {
  connect() {
    this.subscription = consumer.subscriptions.create("NotificationsChannel", {
      received: (data) => this.showToast(data)
    })
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  showToast({ title, message, kind = "info", url }) {
    const icon  = ICONS[kind] || ICONS.info
    const toast = document.createElement("div")

    toast.className = [
      "fixed top-4 right-4 z-[9999] w-80 bg-white rounded-xl shadow-lg",
      "border border-gray-200 p-4 flex items-start gap-3",
      "animate-in slide-in-from-right-4 fade-in duration-300"
    ].join(" ")

    toast.innerHTML = `
      <div class="shrink-0 h-8 w-8 rounded-full ${icon.bg} flex items-center justify-center">
        <svg class="w-4 h-4 ${icon.text}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${icon.path}"/>
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-semibold text-gray-900">${title}</p>
        <p class="text-xs text-gray-500 mt-0.5 leading-relaxed">${message}</p>
        ${url ? `<a href="${url}" class="text-xs font-medium ${icon.text} hover:underline mt-1 inline-block">View →</a>` : ""}
      </div>
      <button class="shrink-0 text-gray-300 hover:text-gray-500 transition-colors" onclick="this.closest('[data-dismiss]').remove()">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>
    `
    toast.dataset.dismiss = ""

    document.body.appendChild(toast)

    // Fade out before removing — asymmetric: instant-ish entry, graceful exit
    setTimeout(() => {
      toast.style.opacity = "0"
      toast.style.transform = "translateX(0.5rem)"
      toast.style.transition = "opacity 200ms ease-out, transform 200ms ease-out"
      setTimeout(() => toast.remove(), 200)
    }, 5800)
  }
}
