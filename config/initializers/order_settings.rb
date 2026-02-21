Rails.application.configure do
  config.x.order_settings = ActiveSupport::OrderedOptions.new
  config.x.order_settings.minutos_base_producao = ENV.fetch("MINUTOS_BASE_PRODUCAO", 60).to_i
  config.x.order_settings.tmp_min = ENV.fetch("TMP_MIN", 2).to_i
  config.x.order_settings.tmp_max = ENV.fetch("TMP_MAX", 20).to_i
  config.x.order_settings.modo_pagamento = ENV.fetch("MODO_PAGAMENTO", "PRE_PAGO")
end
