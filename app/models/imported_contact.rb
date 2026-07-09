# A successfully imported CSV row.
#
# The unique index on (import_id, row_number) is the idempotency key for the
# whole pipeline: re-running a batch job upserts the same rows instead of
# duplicating them.
class ImportedContact < ApplicationRecord
  belongs_to :import

  validates :row_number, presence: true
  validates :name, presence: true
  validates :email, presence: true
end
