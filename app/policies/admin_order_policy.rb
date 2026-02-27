class AdminOrderPolicy < ApplicationPolicy
  def dashboard?
    user&.admin?
  end

  def queue?
    user&.admin?
  end

  def transition?
    user&.admin?
  end
end
