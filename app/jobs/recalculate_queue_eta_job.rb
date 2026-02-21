class RecalculateQueueEtaJob < ApplicationJob
  queue_as :default

  def perform
    Orders::EtaCalculator.call
  end
end
