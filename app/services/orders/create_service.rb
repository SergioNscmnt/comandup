module Orders
  class CreateService
    def initialize(customer:, items:, order_type: :table, table_number: nil, delivery_address: nil, delivery_cep: nil, coupon_code: nil)
      @customer = customer
      @items = Array(items)
      @order_type = order_type
      @table_number = table_number
      @delivery_address = delivery_address
      @delivery_cep = delivery_cep
      @coupon_code = coupon_code
    end

    def call
      raise ArgumentError, "items are required" if @items.empty?

      Order.transaction do
        promotion = find_promotion
        previous_customer_orders_count = previous_customer_orders_count_for_promotion(promotion)

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

        discount = calculate_discount(
          promotion: promotion,
          order: order,
          subtotal: subtotal,
          previous_customer_orders_count: previous_customer_orders_count
        )
        delivery_fee_cents = 0
        delivery_distance_km = nil

        if @order_type.to_sym == :delivery
          if minimum_delivery_order_cents.positive? && subtotal < minimum_delivery_order_cents
            raise ArgumentError, "Pedido mínimo para delivery é #{format_money(minimum_delivery_order_cents)}."
          end

          quote = Orders::DeliveryQuoteService.call(cep: @delivery_cep)
          delivery_fee_cents = quote[:fee_cents].to_i
          delivery_distance_km = quote[:distance_km]
        end

        total = subtotal - discount + delivery_fee_cents
        order.update!(
          subtotal_cents: subtotal,
          discount_cents: discount,
          delivery_fee_cents: delivery_fee_cents,
          delivery_distance_km: delivery_distance_km,
          total_cents: total
        )
        consume_promotion_quantity!(promotion)

        order
      end
    end

    private

    def normalize_table(value)
      raw = value.to_s.strip
      return nil if raw.blank?

      raw.gsub(/\s+/, " ").upcase
    end

    def minimum_delivery_order_cents
      User.company_account&.company_delivery_min_order_cents.to_i
    end

    def find_promotion
      code = @coupon_code.to_s.strip
      return nil if code.blank?

      promotion = Promotion.active_now.where("UPPER(name) = ?", code.upcase).first
      return promotion if promotion

      raise ArgumentError, "Cupom inválido ou expirado."
    end

    def previous_customer_orders_count_for_promotion(promotion)
      return 0 unless promotion&.coupon_category == "primeiro_pedido"
      return 1 if @customer.blank?

      @customer.orders
               .where.not(status: [Order.statuses[:draft], Order.statuses[:canceled], Order.statuses[:payment_failed]])
               .count
    end

    def calculate_discount(promotion:, order:, subtotal:, previous_customer_orders_count:)
      return 0 unless promotion

      validate_promotion_eligibility!(
        promotion: promotion,
        order: order,
        previous_customer_orders_count: previous_customer_orders_count
      )

      if promotion.discount_kind_fixed_value?
        [promotion.discount_value_cents.to_i, subtotal].min
      else
        ((subtotal * promotion.discount_percent.to_d) / 100).round(0).to_i
      end
    end

    def validate_promotion_eligibility!(promotion:, order:, previous_customer_orders_count:)
      category = promotion.coupon_category.to_s
      return if category == "all"
      if category == "primeiro_pedido"
        return if previous_customer_orders_count.zero?

        raise ArgumentError, "Cupom válido apenas para primeiro pedido."
      end
      return if category == "combos" && order.order_items.any? { |item| item.combo_id.present? }
      return if category_matches_products?(order: order, category: category)

      raise ArgumentError, "Cupom inválido para os itens do pedido."
    end

    def category_matches_products?(order:, category:)
      expected = normalize_text(category)
      return false if expected.blank?

      order.order_items.any? do |item|
        item_category_name = item.product&.category&.name
        next false if item_category_name.blank?

        normalize_text(item_category_name).include?(expected)
      end
    end

    def normalize_text(value)
      I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]/, "")
    end

    def consume_promotion_quantity!(promotion)
      return if promotion.blank?
      return if promotion.quantity.nil?
      return if promotion.quantity <= 0

      promotion.update!(quantity: promotion.quantity - 1)
    end

    def format_money(cents)
      value = (cents.to_i / 100.0)
      "R$ #{format('%.2f', value).tr('.', ',')}"
    end
  end
end
