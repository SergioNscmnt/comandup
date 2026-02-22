Rails.application.configure do
  config.x.order_settings = ActiveSupport::OrderedOptions.new
  config.x.order_settings.minutos_base_producao = ENV.fetch("MINUTOS_BASE_PRODUCAO", 60).to_i
  config.x.order_settings.tmp_min = ENV.fetch("TMP_MIN", 2).to_i
  config.x.order_settings.tmp_max = ENV.fetch("TMP_MAX", 20).to_i
  config.x.order_settings.modo_pagamento = ENV.fetch("MODO_PAGAMENTO", "POS_PAGO")
  config.x.order_settings.delivery_fee_per_km_cents = ENV.fetch("DELIVERY_FEE_PER_KM_CENTS", 300).to_i
  config.x.order_settings.delivery_min_fee_cents = ENV.fetch("DELIVERY_MIN_FEE_CENTS", 1000).to_i
end
