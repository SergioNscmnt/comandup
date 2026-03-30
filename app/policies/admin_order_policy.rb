class AdminOrderPolicy < ApplicationPolicy
  def dashboard?
    user&.admin?
  end

  def show?
    user&.admin?
  end

  def queue?
    user&.admin?
  end

  def transition?
    user&.admin?
  end

  def checkout?
    user&.admin?
  end
end
