class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum role: { customer: 0, admin: 1 }

  has_many :orders, foreign_key: :customer_id, dependent: :restrict_with_exception, inverse_of: :customer
  has_many :audit_logs, dependent: :nullify

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :provider, inclusion: { in: ["google_oauth2"] }, allow_nil: true
  validates :uid, presence: true, if: -> { provider.present? }
  validates :uid, uniqueness: { scope: :provider }, allow_nil: true
  validates :company_delivery_radius_km, numericality: { greater_than: 0 }, allow_nil: true
  validates :company_delivery_fee_per_km_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :company_delivery_min_fee_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :company_delivery_min_order_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :company_prep_minutes_base, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :normalize_email

  scope :company_admins, -> { admin.order(:id) }

  def oauth_account?
    provider.present? && uid.present?
  end

  def self.company_account
    admins = company_admins.to_a
    return nil if admins.empty?

    admins.max_by do |admin|
      [
        admin.company_profile_score,
        admin.updated_at.to_i,
        -admin.id.to_i
      ]
    end
  end

  def company_location_query
    [company_address, company_cep, "Brasil"].filter_map { |value| value.to_s.strip.presence }.join(", ")
  end

  def company_profile_score
    fields = [
      company_address,
      company_cep,
      company_delivery_radius_km,
      company_delivery_fee_per_km_cents,
      company_delivery_min_fee_cents,
      company_delivery_min_order_cents
    ]
    fields.count(&:present?)
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
