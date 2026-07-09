# A CSV row that failed validation. Stored with the same
# (import_id, row_number) idempotency key as successful rows, so retried
# batch jobs re-record the same failure instead of duplicating it.
class ImportError < ApplicationRecord
  belongs_to :import

  validates :row_number, presence: true
  validates :message, presence: true
end
