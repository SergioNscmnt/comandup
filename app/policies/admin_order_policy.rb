class AdminOrderPolicy < ApplicationPolicy
  def queue?
    user&.admin?
  end

  def transition?
    user&.admin?
  end
end
