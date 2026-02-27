module Admin
  class DashboardsController < BaseController
    before_action :authorize_dashboard!
    before_action :load_metrics

    def show
      @active_screen = :overview
    end

    def finance
      @active_screen = :finance
    end

    def simulator
      @active_screen = :simulator
    end

    def alerts
      @active_screen = :alerts
    end

    private

    def authorize_dashboard!
      authorize :admin_order, :dashboard?
    end

    def load_metrics
      @metrics = Admin::DashboardMetricsService.new(
        period: params[:period],
        order_type: params[:order_type],
        product_id: params[:product_id],
        scenario: scenario_params
      ).call
      @screen_query = {
        period: @metrics[:period],
        order_type: @metrics[:selected_order_type]
      }.compact
    end

    def scenario_params
      params.permit(
        :discount_percent,
        :combo_factor,
        :price_increase_percent,
        :free_shipping_absorbed,
        :elasticity,
        :margin_min_percent
      )
    end
  end
end
