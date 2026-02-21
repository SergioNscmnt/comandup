class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user.is_a?(Hash) ? user[:user] : user
    @pundit_user = user
    @record = record
  end

  private

  attr_reader :pundit_user

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end
end
