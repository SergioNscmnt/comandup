module Orders
  class CheckoutPricingService
    def self.call(customer:, items:, order_type:, coupon_code:, delivery_cep:)
      new(
        customer: customer,
        items: items,
        order_type: order_type,
        coupon_code: coupon_code,
        delivery_cep: delivery_cep
      ).call
    end

    def initialize(customer:, items:, order_type:, coupon_code:, delivery_cep:)
      @customer = customer
      @items = Array(items)
      @order_type = order_type.to_s
      @coupon_code = coupon_code.to_s
      @delivery_cep = delivery_cep
    end

    def call
      raise ArgumentError, "items are required" if @items.empty?

      line_items = build_line_items
      raise ArgumentError, "valid items are required" if line_items.empty?

      subtotal_cents = line_items.sum { |item| item[:total_cents] }
      promotion = find_promotion
      previous_orders_count = previous_customer_orders_count_for_promotion(promotion)
      discount_cents = calculate_discount(
        promotion: promotion,
        line_items: line_items,
        subtotal_cents: subtotal_cents,
        previous_customer_orders_count: previous_orders_count
      )

      delivery_fee_cents = 0
      delivery_distance_km = nil
      free_shipping = false

      if delivery?
        if minimum_delivery_order_cents.positive? && subtotal_cents < minimum_delivery_order_cents
          raise ArgumentError, "Pedido mínimo para delivery é #{format_money(minimum_delivery_order_cents)}."
        end

        quote = Orders::DeliveryQuoteService.call(
          cep: @delivery_cep,
          subtotal_cents: subtotal_cents
        )
        delivery_fee_cents = quote[:fee_cents].to_i
        delivery_distance_km = quote[:distance_km]
        free_shipping = delivery_fee_cents.zero?
      end

      {
        promotion: promotion,
        line_items: line_items,
        subtotal_cents: subtotal_cents,
        discount_cents: discount_cents,
        delivery_fee_cents: delivery_fee_cents,
        delivery_distance_km: delivery_distance_km,
        total_cents: subtotal_cents - discount_cents + delivery_fee_cents,
        promotion_applied: discount_cents.positive?,
        promotion_name: promotion&.name.to_s,
        free_shipping: free_shipping,
        minimum_delivery_order_cents: minimum_delivery_order_cents
      }
    end

    private

    def build_line_items
      @items.filter_map do |item|
        quantity = item.fetch(:quantity, 1).to_i
        next if quantity <= 0

        if item[:product_id].present?
          product = Product.find(item[:product_id])
          unit_cents = product.price_cents
          {
            product: product,
            combo: nil,
            quantity: quantity,
            unit_cents: unit_cents,
            total_cents: unit_cents * quantity,
            notes: item[:notes].to_s.strip.presence
          }
        elsif item[:combo_id].present?
          combo = Combo.find(item[:combo_id])
          unit_cents = combo.price_cents
          {
            product: nil,
            combo: combo,
            quantity: quantity,
            unit_cents: unit_cents,
            total_cents: unit_cents * quantity,
            notes: item[:notes].to_s.strip.presence
          }
        end
      end
    end

    def delivery?
      @order_type == "delivery"
    end

    def minimum_delivery_order_cents
      User.company_account&.company_delivery_min_order_cents.to_i
    end

    def find_promotion
      code = @coupon_code.strip
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

    def calculate_discount(promotion:, line_items:, subtotal_cents:, previous_customer_orders_count:)
      return 0 unless promotion

      validate_promotion_eligibility!(
        promotion: promotion,
        line_items: line_items,
        previous_customer_orders_count: previous_customer_orders_count
      )

      if promotion.discount_kind_fixed_value?
        [promotion.discount_value_cents.to_i, subtotal_cents].min
      else
        ((subtotal_cents * promotion.discount_percent.to_d) / 100).round(0).to_i
      end
    end

    def validate_promotion_eligibility!(promotion:, line_items:, previous_customer_orders_count:)
      category = promotion.coupon_category.to_s
      return if category == "all"
      if category == "primeiro_pedido"
        return if previous_customer_orders_count.zero?

        raise ArgumentError, "Cupom válido apenas para primeiro pedido."
      end
      return if category == "combos" && line_items.any? { |item| item[:combo].present? }
      return if category_matches_products?(line_items: line_items, category: category)

      raise ArgumentError, "Cupom inválido para os itens do pedido."
    end

    def category_matches_products?(line_items:, category:)
      expected = normalize_text(category)
      return false if expected.blank?

      line_items.any? do |item|
        item_category_name = item[:product]&.category&.name
        next false if item_category_name.blank?

        normalize_text(item_category_name).include?(expected)
      end
    end

    def normalize_text(value)
      I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]/, "")
    end

    def format_money(cents)
      value = (cents.to_i / 100.0)
      "R$ #{format('%.2f', value).tr('.', ',')}"
    end
  end
end
