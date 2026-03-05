module Orders
  class CreateService
    def initialize(customer:, items:, order_type: :table, table_number: nil, delivery_address: nil, delivery_cep: nil, coupon_code: nil, idempotency_key: nil)
      @customer = customer
      @items = Array(items)
      @order_type = order_type
      @table_number = table_number
      @delivery_address = delivery_address
      @delivery_cep = delivery_cep
      @coupon_code = coupon_code
      @idempotency_key = idempotency_key.to_s.strip.presence
    end

    def call
      raise ArgumentError, "items are required" if @items.empty?
      existing_order = find_existing_idempotent_order
      return existing_order if existing_order

      Order.transaction do
        pricing = Orders::CheckoutPricingService.call(
          customer: @customer,
          items: @items,
          order_type: @order_type,
          coupon_code: @coupon_code,
          delivery_cep: @delivery_cep
        )
        promotion = pricing[:promotion]

        order = Order.create!(
          customer: @customer,
          order_type: @order_type,
          table_number: normalize_table(@table_number),
          delivery_address: @delivery_address.presence,
          service_token: SecureRandom.hex(16),
          idempotency_key: @idempotency_key,
          status: :draft
        )

        pricing[:line_items].each do |item|
          order.order_items.create!(
            product: item[:product],
            combo: item[:combo],
            quantity: item[:quantity],
            unit_price_cents: item[:unit_cents],
            total_cents: item[:total_cents],
            notes: item[:notes]
          )
        end

        order.update!(
          subtotal_cents: pricing[:subtotal_cents],
          discount_cents: pricing[:discount_cents],
          delivery_fee_cents: pricing[:delivery_fee_cents],
          delivery_distance_km: pricing[:delivery_distance_km],
          total_cents: pricing[:total_cents]
        )
        consume_promotion_quantity!(promotion)

        order
      end
    rescue ActiveRecord::RecordNotUnique
      existing_order = find_existing_idempotent_order
      return existing_order if existing_order.present?

      raise
    end

    private

    def find_existing_idempotent_order
      return nil if @idempotency_key.blank?

      scope = Order.where(idempotency_key: @idempotency_key)
      scope = if @customer.present?
                scope.where(customer_id: @customer.id)
              else
                scope.where(customer_id: nil)
              end

      scope.order(id: :desc).first
    end

    def normalize_table(value)
      raw = value.to_s.strip
      return nil if raw.blank?

      raw.gsub(/\s+/, " ").upcase
    end

    def consume_promotion_quantity!(promotion)
      return if promotion.blank?
      return if promotion.quantity.nil?
      return if promotion.quantity <= 0

      promotion.update!(quantity: promotion.quantity - 1)
    end

  end
end
