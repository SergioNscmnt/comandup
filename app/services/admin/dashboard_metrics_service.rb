module Admin
  class DashboardMetricsService
    DEFAULT_TABLES = 10
    PERIODS = {
      "day" => -> { 1.day.ago.beginning_of_day },
      "week" => -> { 1.week.ago.beginning_of_day },
      "month" => -> { 1.month.ago.beginning_of_day },
      "six_months" => -> { 6.months.ago.beginning_of_day },
      "year" => -> { 1.year.ago.beginning_of_day }
    }.freeze
    COMPLETED_STATUSES = %w[ready delivered].freeze

    def initialize(period:, order_type:, product_id: nil, scenario: {}, table_state: nil)
      @period = PERIODS.key?(period) ? period : "month"
      @order_type = Order.order_types.key?(order_type) ? order_type : nil
      @product_id = product_id.to_i.positive? ? product_id.to_i : nil
      @scenario_input = normalize_scenario_input(scenario || {})
      @table_state = %w[all occupied free].include?(table_state) ? table_state : "all"
    end

    def call
      relation = filtered_orders
      completed_orders = relation.where(status: COMPLETED_STATUSES)
      canceled_orders = relation.where(status: :canceled)
      open_orders = relation.where(status: Order::OPEN_STATUSES)

      completed_count = completed_orders.count
      total_count = relation.count
      canceled_count = canceled_orders.count

      revenue_cents = completed_orders.sum(:total_cents)
      discounts_cents = completed_orders.sum(:discount_cents)
      gross_revenue_cents = completed_orders.sum(:subtotal_cents) + completed_orders.sum(:delivery_fee_cents)

      costs = cost_breakdown(completed_orders)
      financials = financials(gross_revenue_cents:, revenue_cents:, discounts_cents:, costs:)

      simulation = build_simulation(completed_orders)

      {
        period: @period,
        selected_order_type: @order_type,
        selected_product_id: @product_id,
        from: started_at.to_date,
        to: Time.current.to_date,
        totals: {
          total_orders: total_count,
          completed_orders: completed_count,
          canceled_orders: canceled_count,
          open_orders: open_orders.count,
          cancel_rate: percentage(canceled_count, total_count),
          revenue_cents: revenue_cents,
          gross_revenue_cents: gross_revenue_cents,
          discounts_cents: discounts_cents,
          average_ticket_cents: completed_count.zero? ? 0 : (revenue_cents / completed_count.to_f).round,
          gross_margin_percent: percentage(financials[:gross_profit_cents], revenue_cents),
          operating_margin_percent: percentage(financials[:operating_profit_cents], revenue_cents)
        },
        financials: financials,
        by_mode: metrics_by_mode(relation),
        trend: daily_trend(completed_orders),
        table_dashboard: build_table_dashboard,
        alerts: alerts(
          cancel_rate: percentage(canceled_count, total_count),
          operating_margin_percent: financials[:operating_margin_percent],
          discount_rate: percentage(discounts_cents, gross_revenue_cents)
        ),
        simulation: simulation
      }
    end

    private

    def normalize_scenario_input(raw)
      {
        discount_percent: to_decimal(raw[:discount_percent], default: 0.0),
        combo_factor: to_decimal(raw[:combo_factor], default: 1.0),
        price_increase_percent: to_decimal(raw[:price_increase_percent], default: 0.0),
        free_shipping_absorbed: truthy?(raw[:free_shipping_absorbed]),
        elasticity: to_decimal(raw[:elasticity], default: -1.2),
        margin_min_percent: to_decimal(raw[:margin_min_percent], default: 25.0)
      }
    end

    def filtered_orders
      scoped = Order.where(created_at: started_at..Time.current)
      scoped = scoped.where(order_type: Order.order_types[@order_type]) if @order_type
      scoped
    end

    def started_at
      @started_at ||= PERIODS.fetch(@period).call
    end

    def cost_breakdown(completed_orders)
      rows = OrderItem
        .joins(:order)
        .left_joins(product: :product_cost)
        .where(orders: { id: completed_orders.select(:id) })
        .pluck(
          :quantity,
          :unit_price_cents,
          Arel.sql("COALESCE(product_costs.ingredients_cents, 0)"),
          Arel.sql("COALESCE(product_costs.packaging_cents, 0)"),
          Arel.sql("COALESCE(product_costs.losses_percent, 0)"),
          Arel.sql("COALESCE(product_costs.labor_cents, 0)"),
          Arel.sql("COALESCE(product_costs.fixed_allocation_cents, 0)"),
          Arel.sql("COALESCE(product_costs.channel_fee_percent, 0)")
        )

      rows.each_with_object({ cpv_cents: 0, variable_costs_cents: 0, fixed_allocated_cents: 0 }) do |row, acc|
        qty, unit_price, ingredients, packaging, losses_percent, labor, fixed_allocation, channel_fee_percent = row
        quantity = qty.to_i
        price = unit_price.to_i
        loss_multiplier = 1 + (losses_percent.to_f / 100.0)

        cpv_unit = (ingredients.to_i * loss_multiplier).round
        variable_unit = packaging.to_i + ((price * (channel_fee_percent.to_f / 100.0)).round)
        fixed_unit = labor.to_i + fixed_allocation.to_i

        acc[:cpv_cents] += cpv_unit * quantity
        acc[:variable_costs_cents] += variable_unit * quantity
        acc[:fixed_allocated_cents] += fixed_unit * quantity
      end
    end

    def financials(gross_revenue_cents:, revenue_cents:, discounts_cents:, costs:)
      gross_profit_cents = revenue_cents - costs[:cpv_cents] - costs[:variable_costs_cents]
      operating_profit_cents = gross_profit_cents - costs[:fixed_allocated_cents]

      {
        gross_revenue_cents: gross_revenue_cents,
        discounts_cents: discounts_cents,
        net_revenue_cents: revenue_cents,
        cpv_cents: costs[:cpv_cents],
        variable_costs_cents: costs[:variable_costs_cents],
        fixed_allocated_cents: costs[:fixed_allocated_cents],
        gross_profit_cents: gross_profit_cents,
        operating_profit_cents: operating_profit_cents,
        gross_margin_percent: percentage(gross_profit_cents, revenue_cents),
        operating_margin_percent: percentage(operating_profit_cents, revenue_cents)
      }
    end

    def metrics_by_mode(relation)
      grouped_total = relation.group(:order_type).count
      grouped_completed = relation.where(status: COMPLETED_STATUSES).group(:order_type).count
      grouped_revenue = relation.where(status: COMPLETED_STATUSES).group(:order_type).sum(:total_cents)
      relation_total = grouped_total.values.sum

      Order.order_types.keys.map do |mode|
        total = grouped_total.fetch(Order.order_types[mode], 0)
        {
          mode: mode,
          total_orders: total,
          completed_orders: grouped_completed.fetch(Order.order_types[mode], 0),
          revenue_cents: grouped_revenue.fetch(Order.order_types[mode], 0),
          participation: percentage(total, relation_total)
        }
      end
    end

    def daily_trend(completed_orders)
      completed_orders
        .group(Arel.sql("DATE(created_at)"))
        .order(Arel.sql("DATE(created_at)"))
        .pluck(
          Arel.sql("DATE(created_at)"),
          Arel.sql("COUNT(*)"),
          Arel.sql("COALESCE(SUM(total_cents), 0)"),
          Arel.sql("COALESCE(SUM(discount_cents), 0)")
        )
        .map do |date, orders_count, revenue_cents, discounts_cents|
          {
            date: date,
            orders_count: orders_count,
            revenue_cents: revenue_cents,
            discounts_cents: discounts_cents
          }
        end
    end

    def alerts(cancel_rate:, operating_margin_percent:, discount_rate:)
      alerts = []
      if operating_margin_percent.negative?
        alerts << {
          severity: :critical,
          title: "Margem operacional negativa",
          metric: "#{operating_margin_percent.round(2)}%",
          recommendation: "Revisar preço, custos e campanhas imediatamente."
        }
      elsif operating_margin_percent < 25
        alerts << {
          severity: :warning,
          title: "Margem operacional abaixo da meta",
          metric: "#{operating_margin_percent.round(2)}%",
          recommendation: "Ajustar mix e custos para voltar acima de 25%."
        }
      end

      if cancel_rate > 5
        alerts << {
          severity: :warning,
          title: "Taxa de cancelamento elevada",
          metric: "#{cancel_rate.round(2)}%",
          recommendation: "Investigar gargalo operacional e falhas de prazo."
        }
      end

      if discount_rate > 20
        alerts << {
          severity: :info,
          title: "Descontos em patamar alto",
          metric: "#{discount_rate.round(2)}%",
          recommendation: "Validar se o ganho de volume compensa a perda de margem."
        }
      end

      alerts
    end

    def build_simulation(completed_orders)
      products = aggregate_products(completed_orders)
      avg_delivery_fee = average_delivery_fee_cents(completed_orders)
      avg_items = average_items_per_order(completed_orders)
      shipping_unit = if @scenario_input[:free_shipping_absorbed] && avg_items.positive?
                        (avg_delivery_fee / avg_items.to_f).round
                      else
                        0
                      end

      simulated_rows = products.map { |product| simulate_product(product, @scenario_input, shipping_unit) }
      current_summary = summarize_simulation(simulated_rows)
      recommendation = best_offer_recommendation(products, shipping_unit)

      hero_product = simulated_rows
        .select { |row| row[:baseline_profit_cents].positive? }
        .max_by { |row| row[:baseline_profit_cents] }

      problem_products = simulated_rows
        .select { |row| row[:baseline_qty] > 0 && (row[:baseline_margin_percent] < @scenario_input[:margin_min_percent] || row[:baseline_profit_cents].negative?) }
        .sort_by { |row| row[:baseline_margin_percent] }
        .first(5)

      {
        input: @scenario_input,
        current: current_summary,
        recommendation: recommendation,
        hero_product: hero_product,
        problem_products: problem_products,
        products: simulated_rows.sort_by { |row| -row[:baseline_profit_cents] }
      }
    end

    def aggregate_products(completed_orders)
      scope = OrderItem
        .joins(:order)
        .joins(:product)
        .left_joins(product: :product_cost)
        .where(orders: { id: completed_orders.select(:id) })
      scope = scope.where(product_id: @product_id) if @product_id

      scope.group(
        :product_id,
        "products.name",
        "product_costs.ingredients_cents",
        "product_costs.packaging_cents",
        "product_costs.losses_percent",
        "product_costs.labor_cents",
        "product_costs.fixed_allocation_cents",
        "product_costs.channel_fee_percent"
      ).pluck(
        :product_id,
        "products.name",
        Arel.sql("SUM(order_items.quantity)"),
        Arel.sql("SUM(order_items.total_cents)"),
        Arel.sql("COALESCE(product_costs.ingredients_cents, 0)"),
        Arel.sql("COALESCE(product_costs.packaging_cents, 0)"),
        Arel.sql("COALESCE(product_costs.losses_percent, 0)"),
        Arel.sql("COALESCE(product_costs.labor_cents, 0)"),
        Arel.sql("COALESCE(product_costs.fixed_allocation_cents, 0)"),
        Arel.sql("COALESCE(product_costs.channel_fee_percent, 0)")
      ).map do |row|
        {
          product_id: row[0],
          product_name: row[1],
          qty: row[2].to_f,
          revenue_cents: row[3].to_f,
          ingredients_cents: row[4].to_f,
          packaging_cents: row[5].to_f,
          losses_percent: row[6].to_f,
          labor_cents: row[7].to_f,
          fixed_allocation_cents: row[8].to_f,
          channel_fee_percent: row[9].to_f
        }
      end
    end

    def simulate_product(product, scenario, shipping_unit_cents)
      baseline_qty = product[:qty]
      baseline_revenue = product[:revenue_cents]
      baseline_price = baseline_qty.positive? ? (baseline_revenue / baseline_qty) : 0.0

      fixed_cost_unit = (product[:ingredients_cents] * (1 + product[:losses_percent] / 100.0)) +
                        product[:packaging_cents] +
                        product[:labor_cents] +
                        product[:fixed_allocation_cents]

      baseline_channel_fee_unit = baseline_price * (product[:channel_fee_percent] / 100.0)
      baseline_unit_cost = fixed_cost_unit + baseline_channel_fee_unit
      baseline_cost_total = baseline_unit_cost * baseline_qty
      baseline_profit = baseline_revenue - baseline_cost_total
      baseline_margin = percentage(baseline_profit, baseline_revenue)

      price_multiplier = (1 - scenario[:discount_percent] / 100.0) *
                         (1 + scenario[:price_increase_percent] / 100.0) *
                         scenario[:combo_factor]
      price_multiplier = 0 if price_multiplier.negative?

      scenario_price = baseline_price * price_multiplier
      scenario_qty = if baseline_price.positive? && baseline_qty.positive?
                       baseline_qty * ((scenario_price / baseline_price) ** scenario[:elasticity])
                     else
                       0.0
                     end
      scenario_qty = 0.0 if scenario_qty.negative?

      scenario_channel_fee_unit = scenario_price * (product[:channel_fee_percent] / 100.0)
      scenario_unit_cost = fixed_cost_unit + scenario_channel_fee_unit + shipping_unit_cents
      scenario_revenue = scenario_price * scenario_qty
      scenario_cost_total = scenario_unit_cost * scenario_qty
      scenario_profit = scenario_revenue - scenario_cost_total
      scenario_margin = percentage(scenario_profit, scenario_revenue)

      {
        product_id: product[:product_id],
        product_name: product[:product_name],
        baseline_qty: baseline_qty.round(2),
        baseline_revenue_cents: baseline_revenue.round,
        baseline_profit_cents: baseline_profit.round,
        baseline_margin_percent: baseline_margin,
        scenario_qty: scenario_qty.round(2),
        scenario_revenue_cents: scenario_revenue.round,
        scenario_profit_cents: scenario_profit.round,
        scenario_margin_percent: scenario_margin,
        margin_status: margin_status(scenario_margin)
      }
    end

    def summarize_simulation(rows)
      baseline_qty = rows.sum { |row| row[:baseline_qty] }
      baseline_revenue = rows.sum { |row| row[:baseline_revenue_cents] }
      baseline_profit = rows.sum { |row| row[:baseline_profit_cents] }

      scenario_qty = rows.sum { |row| row[:scenario_qty] }
      scenario_revenue = rows.sum { |row| row[:scenario_revenue_cents] }
      scenario_profit = rows.sum { |row| row[:scenario_profit_cents] }

      {
        baseline_qty: baseline_qty.round(2),
        baseline_revenue_cents: baseline_revenue,
        baseline_profit_cents: baseline_profit,
        baseline_margin_percent: percentage(baseline_profit, baseline_revenue),
        scenario_qty: scenario_qty.round(2),
        scenario_revenue_cents: scenario_revenue,
        scenario_profit_cents: scenario_profit,
        scenario_margin_percent: percentage(scenario_profit, scenario_revenue),
        volume_change_percent: percentage(scenario_qty - baseline_qty, baseline_qty),
        profit_change_percent: percentage(scenario_profit - baseline_profit, baseline_profit)
      }
    end

    def best_offer_recommendation(products, shipping_unit_cents)
      candidates = [
        { name: "Sem oferta", discount_percent: 0, combo_factor: 1, price_increase_percent: 0, free_shipping_absorbed: false },
        { name: "Desconto", discount_percent: @scenario_input[:discount_percent], combo_factor: 1, price_increase_percent: 0, free_shipping_absorbed: false },
        { name: "Combo", discount_percent: 0, combo_factor: @scenario_input[:combo_factor], price_increase_percent: 0, free_shipping_absorbed: false },
        { name: "Frete grátis", discount_percent: 0, combo_factor: 1, price_increase_percent: 0, free_shipping_absorbed: true },
        { name: "Reajuste", discount_percent: 0, combo_factor: 1, price_increase_percent: @scenario_input[:price_increase_percent], free_shipping_absorbed: false }
      ]

      evaluated = candidates.map do |candidate|
        input = @scenario_input.merge(candidate.slice(:discount_percent, :combo_factor, :price_increase_percent, :free_shipping_absorbed))
        shipping = candidate[:free_shipping_absorbed] ? shipping_unit_cents : 0
        summary = summarize_simulation(products.map { |product| simulate_product(product, input, shipping) })
        {
          offer_name: candidate[:name],
          summary: summary,
          valid_margin: summary[:scenario_margin_percent] >= @scenario_input[:margin_min_percent],
          valid_volume: summary[:volume_change_percent] >= -5
        }
      end

      best = evaluated
        .select { |item| item[:valid_margin] && item[:valid_volume] }
        .max_by { |item| item[:summary][:scenario_profit_cents] }

      return { selected: nil, candidates: evaluated } unless best

      {
        selected: {
          offer_name: best[:offer_name],
          scenario_profit_cents: best[:summary][:scenario_profit_cents],
          scenario_margin_percent: best[:summary][:scenario_margin_percent],
          volume_change_percent: best[:summary][:volume_change_percent]
        },
        candidates: evaluated
      }
    end

    def margin_status(margin_percent)
      return "negative" if margin_percent.negative?
      return "below_target" if margin_percent < @scenario_input[:margin_min_percent]

      "healthy"
    end

    def average_delivery_fee_cents(completed_orders)
      delivery_orders = completed_orders.where(order_type: Order.order_types[:delivery])
      count = delivery_orders.count
      return 0 if count.zero?

      (delivery_orders.sum(:delivery_fee_cents) / count.to_f).round
    end

    def average_items_per_order(completed_orders)
      totals = OrderItem
        .joins(:order)
        .where(orders: { id: completed_orders.select(:id) })
        .group(:order_id)
        .sum(:quantity)
      count = totals.size
      return 0 if count.zero?

      totals.values.sum / count.to_f
    end

    def to_decimal(value, default:)
      return default if value.nil?

      text = value.to_s.strip
      return default if text.empty?

      text = text.tr(",", ".")
      Float(text)
    rescue ArgumentError, TypeError
      default
    end

    def truthy?(value)
      value.to_s == "1" || value.to_s.casecmp("true").zero?
    end

    def build_table_dashboard
      table_orders = Order
        .where(order_type: :table)
        .includes(:order_items, :customer)
        .order(created_at: :desc, id: :desc)

      grouped = table_orders.group_by(&:dashboard_table_key).reject { |key, _| key.blank? }
      total_tables = [DEFAULT_TABLES, grouped.keys.max.to_i].max
      now = Time.current

      cards = (1..total_tables).map do |number|
        build_table_card(number:, orders: grouped[number] || [], reference_time: now)
      end

      active_cards = cards.select { |card| card[:occupied] }
      pending_orders = grouped.values.flatten.select(&:active_for_table_dashboard?)

      {
        selected_state: @table_state,
        filters: [
          { key: "all", label: "Todas", count: cards.size },
          { key: "occupied", label: "Ocupadas", count: cards.count { |card| card[:occupied] } },
          { key: "free", label: "Livres", count: cards.count { |card| card[:state] == :free } }
        ],
        totals: {
          total_tables: total_tables,
          occupied_tables: active_cards.size,
          free_tables: cards.count { |card| card[:state] == :free },
          attention_tables: cards.count { |card| card[:state] == :attention },
          average_minutes: average_table_minutes(active_cards),
          total_open_cents: active_cards.sum { |card| card[:current_total_cents] },
          pending_tickets: pending_orders.size
        },
        kitchen: {
          average_wait_minutes: average_wait_minutes(pending_orders),
          received_count: pending_orders.count(&:received?),
          in_production_count: pending_orders.count(&:in_production?),
          ready_count: pending_orders.count(&:ready?)
        },
        tables: filter_table_cards(cards)
      }
    end

    def build_table_card(number:, orders:, reference_time:)
      active_orders = orders.select(&:active_for_table_dashboard?)
      latest_order = active_orders.max_by(&:created_at) || orders.max_by(&:created_at)

      if active_orders.empty?
        return {
          number: number,
          label: format("Mesa %02d", number),
          state: :free,
          occupied: false,
          state_label: "Livre",
          elapsed_minutes: 0,
          elapsed_label: "--:--",
          current_total_cents: 0,
          ticket_count: 0,
          summary: "Mesa disponível para abrir comanda.",
          note: nil,
          customer_name: nil,
          action_label: "Abrir Comanda"
        }
      end

      attention = active_orders.any? { |order| order.attention_for_table_dashboard?(reference_time:) }
      current_total_cents = active_orders.sum(&:total_cents)
      latest_elapsed_minutes = latest_order.dashboard_elapsed_minutes(reference_time:)
      latest_elapsed_label = minutes_to_clock(latest_elapsed_minutes)
      latest_status = attention ? :attention : :occupied

      {
        number: number,
        label: format("Mesa %02d", number),
        state: latest_status,
        occupied: true,
        state_label: attention ? "Atenção" : "Ocupada",
        elapsed_minutes: latest_elapsed_minutes,
        elapsed_label: latest_elapsed_label,
        current_total_cents: current_total_cents,
        ticket_count: active_orders.size,
        summary: table_summary(active_orders),
        note: table_note(active_orders, latest_order, reference_time:),
        customer_name: latest_order&.customer&.name,
        action_label: "Ver fila",
        order_id: latest_order&.id
      }
    end

    def table_summary(active_orders)
      if active_orders.any?(&:in_production?)
        "#{active_orders.count(&:in_production?)} pedido(s) em preparo"
      elsif active_orders.any?(&:received?)
        "#{active_orders.count(&:received?)} pedido(s) aguardando cozinha"
      elsif active_orders.all?(&:ready?)
        "Todos os pedidos prontos para servir"
      else
        "#{active_orders.size} ticket(s) em aberto"
      end
    end

    def table_note(active_orders, latest_order, reference_time:)
      return "Pedido pronto aguardando fechamento" if active_orders.any? { |order| order.ready? && order.ready_at.present? && order.ready_at <= 5.minutes.ago }
      return "Tempo acima do ETA em #{latest_order.dashboard_elapsed_minutes(reference_time:) - latest_order.eta_minutes} min" if latest_order.eta_minutes.present? && latest_order.dashboard_elapsed_minutes(reference_time:) > latest_order.eta_minutes
      return "Ticket atual: #{latest_order.human_status}" if latest_order.present?

      nil
    end

    def filter_table_cards(cards)
      case @table_state
      when "occupied"
        cards.select { |card| card[:occupied] }
      when "free"
        cards.select { |card| card[:state] == :free }
      else
        cards
      end
    end

    def average_table_minutes(cards)
      return 0 if cards.empty?

      (cards.sum { |card| card[:elapsed_minutes] } / cards.size.to_f).round
    end

    def average_wait_minutes(orders)
      return 0 if orders.empty?

      (orders.sum { |order| order.dashboard_elapsed_minutes } / orders.size.to_f).round
    end

    def minutes_to_clock(minutes)
      total_minutes = minutes.to_i
      format("%02d:%02d", total_minutes / 60, total_minutes % 60)
    end

    def percentage(part, whole)
      return 0.0 if whole.to_f.zero?

      ((part.to_f / whole.to_f) * 100).round(2)
    end
  end
end
