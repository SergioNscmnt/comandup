import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const STATUS_LABELS = {
  draft: "Rascunho",
  received: "Recebido",
  in_production: "Em produção",
  ready: "Pronto",
  delivered: "Finalizado",
  canceled: "Cancelado",
  payment_failed: "Falha no pagamento"
}

const STATUS_COPY = {
  draft: "Aguardando confirmação do pedido.",
  received: "Recebemos seu pedido e ele está na fila.",
  in_production: "Seu pedido está em preparo.",
  ready: "Seu pedido está pronto para retirada/entrega.",
  delivered: "Pedido finalizado. Obrigado!",
  canceled: "Pedido cancelado.",
  payment_failed: "Falha no pagamento."
}

const READY_COPY_TABLE = "Seu pedido está pronto para servir na mesa."

export default class extends Controller {
  static values = {
    orderId: Number,
    tableOrder: Boolean
  }

  static targets = ["statusPill", "statusLabel", "queuePosition", "etaMinutes", "statusCopy"]

  connect() {
    if (!this.hasOrderIdValue) return

    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "OrderChannel", order_id: this.orderIdValue },
      { received: (data) => this.applyUpdate(data) }
    )
  }

  disconnect() {
    if (this.subscription) this.consumer.subscriptions.remove(this.subscription)
    if (this.consumer) this.consumer.disconnect()
  }

  applyUpdate(data) {
    if (!data || !data.status) return

    this.updateStatusPill(data.status)
    this.updateText(this.queuePositionTarget, data.queue_position)
    this.updateText(this.etaMinutesTarget, data.eta_minutes)
    this.updateStatusCopy(data.status)
  }

  updateStatusPill(status) {
    this.statusPillTarget.className = `status-pill status-${status}`
    this.statusLabelTarget.textContent = STATUS_LABELS[status] || status
  }

  updateStatusCopy(status) {
    if (status === "ready" && this.tableOrderValue) {
      this.statusCopyTarget.textContent = READY_COPY_TABLE
      return
    }

    this.statusCopyTarget.textContent = STATUS_COPY[status] || STATUS_COPY.draft
  }

  updateText(target, value) {
    target.textContent = value ?? "-"
  }
}
