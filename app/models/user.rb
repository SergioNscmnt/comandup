class User < ApplicationRecord
  has_secure_password validations: false

  enum role: { customer: 0, admin: 1 }

  has_many :orders, foreign_key: :customer_id, dependent: :restrict_with_exception, inverse_of: :customer
  has_many :audit_logs, dependent: :nullify

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :provider, inclusion: { in: ["google_oauth2"] }, allow_nil: true
  validates :uid, presence: true, if: -> { provider.present? }
  validates :uid, uniqueness: { scope: :provider }, allow_nil: true
  validates :password_digest, presence: true, unless: :oauth_account?
  validates :password, presence: true, if: :password_required?
  validates :password, length: { minimum: 8 }, if: :password_present_for_local_account?

  before_validation :normalize_email

  def oauth_account?
    provider.present? && uid.present?
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def password_required?
    return false if oauth_account?

    new_record? || password.present?
  end

  def password_present_for_local_account?
    !oauth_account? && password.present?
  end
end
