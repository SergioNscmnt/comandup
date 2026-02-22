module Orders
  class TransitionService
    class InvalidTransition < StandardError; end

    def initialize(order:, actor:, reason: nil)
      @order = order
      @actor = actor
      @reason = reason
    end

    def confirm_received
      transition!(to: :received, from: [:draft], event: "confirm_received")
    end

    def cancel_by_customer
      transition!(to: :canceled, from: [:received], event: "cancel")
    end

    def start_production
      top_order_id = Order.open_queue.first&.id
      bypass = top_order_id.present? && top_order_id != @order.id
      transition!(to: :in_production, from: [:received], event: "start_production", bypass: bypass)
    end

    def finish
      transition!(to: :ready, from: [:in_production], event: "finish")
    end

    def mark_delivered
      transition!(to: :delivered, from: [:ready], event: "mark_delivered")
    end

    private

    def transition!(to:, from:, event:, bypass: false)
      @order.with_lock do
        raise InvalidTransition, "invalid transition" unless from.map(&:to_s).include?(@order.status)

        from_status = @order.status
        updates = { status: to }
        timestamp_field = status_timestamp_field(to)
        updates[timestamp_field] = Time.current if timestamp_field
        @order.update!(updates)

        AuditLog.create!(
          order: @order,
          user: @actor,
          event: event,
          from_status: Order.statuses[from_status],
          to_status: Order.statuses[to.to_s],
          reason: @reason,
          metadata: metadata_payload(bypass)
        )
      end

      RecalculateQueueEtaJob.perform_later
      BroadcastOrderUpdateJob.perform_later(@order.id)
      BroadcastQueueUpdateJob.perform_later
      @order
    end

    def status_timestamp_field(status)
      {
        received: :received_at,
        in_production: :started_at,
        ready: :ready_at,
        delivered: :delivered_at,
        canceled: :canceled_at
      }[status.to_sym]
    end

    def metadata_payload(bypass)
      JSON.generate(bypass ? { queue_bypass: true } : {})
    end
  end
end
