module Admin
  module DashboardsHelper
    def dashboard_mode_color(mode)
      case mode.to_s
      when "delivery" then "#0ea5a4"
      when "pickup" then "#2563eb"
      when "table" then "#f59e0b"
      else "#94a3b8"
      end
    end

    def dashboard_mode_pie_gradient(by_mode)
      total = by_mode.sum { |row| row[:total_orders].to_f }
      return "conic-gradient(#e2e8f0 0 100%)" if total <= 0

      start = 0.0
      segments = by_mode.map do |row|
        pct = (row[:total_orders].to_f / total) * 100
        finish = start + pct
        color = dashboard_mode_color(row[:mode])
        segment = "#{color} #{start.round(2)}% #{finish.round(2)}%"
        start = finish
        segment
      end

      "conic-gradient(#{segments.join(', ')})"
    end

    def dashboard_line_points(values, width: 560, height: 220, padding: 24)
      return "" if values.empty?

      max = values.max.to_f
      min = values.min.to_f
      span = (max - min)
      span = 1.0 if span.zero?
      inner_w = width - (padding * 2)
      inner_h = height - (padding * 2)
      step = values.size > 1 ? inner_w.to_f / (values.size - 1) : 0

      values.each_with_index.map do |value, index|
        x = padding + (step * index)
        y = padding + inner_h - (((value - min) / span) * inner_h)
        "#{x.round(2)},#{y.round(2)}"
      end.join(" ")
    end
  end
end
