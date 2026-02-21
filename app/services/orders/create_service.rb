module Orders
  class CreateService
    def initialize(customer:, items:, order_type: :table, table_number: nil, delivery_address: nil)
      @customer = customer
      @items = Array(items)
      @order_type = order_type
      @table_number = table_number
      @delivery_address = delivery_address
    end

    def call
      raise ArgumentError, "items are required" if @items.empty?

      Order.transaction do
        order = Order.create!(
          customer: @customer,
          order_type: @order_type,
          table_number: normalize_table(@table_number),
          delivery_address: @delivery_address.presence,
          service_token: SecureRandom.hex(16),
          status: :draft
        )

        subtotal = 0

        @items.each do |item|
          quantity = item.fetch(:quantity, 1).to_i
          next if quantity <= 0

          if item[:product_id].present?
            product = Product.find(item[:product_id])
            unit = product.price_cents
            order.order_items.create!(
              product: product,
              quantity: quantity,
              unit_price_cents: unit,
              total_cents: unit * quantity,
              notes: item[:notes].to_s.strip.presence
            )
            subtotal += unit * quantity
          elsif item[:combo_id].present?
            combo = Combo.find(item[:combo_id])
            unit = combo.price_cents
            order.order_items.create!(
              combo: combo,
              quantity: quantity,
              unit_price_cents: unit,
              total_cents: unit * quantity,
              notes: item[:notes].to_s.strip.presence
            )
            subtotal += unit * quantity
          end
        end

        raise ArgumentError, "valid items are required" if order.order_items.empty?

        discount = 0
        total = subtotal - discount
        order.update!(subtotal_cents: subtotal, discount_cents: discount, total_cents: total)

        order
      end
    end

    private

    def normalize_table(value)
      raw = value.to_s.strip
      return nil if raw.blank?

      raw.gsub(/\s+/, " ").upcase
    end
  end
end
