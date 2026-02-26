module Orders
  class EtaCalculator
    def self.call
      open_orders = Order.open_queue.to_a
      count = open_orders.length

      tmp = (base_prep_minutes.to_f / [count, 1].max)
      tmp = [[tmp, settings.tmp_min].max, settings.tmp_max].min

      Order.transaction do
        open_orders.each_with_index do |order, index|
          position = index + 1
          eta = (tmp * position).ceil
          order.update!(queue_position: position, eta_minutes: eta)
          BroadcastOrderUpdateJob.perform_later(order.id)
        end
      end
    end

    def self.settings
      Rails.configuration.x.order_settings
    end

    def self.base_prep_minutes
      company_value = User.company_account&.company_prep_minutes_base.to_i
      return company_value if company_value.positive?

      settings.minutos_base_producao.to_i
    end
  end
end
