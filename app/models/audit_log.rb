class AuditLog < ApplicationRecord
  belongs_to :order
  belongs_to :user, optional: true

  validates :event, presence: true
end
