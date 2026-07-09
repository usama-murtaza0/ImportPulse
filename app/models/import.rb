# An Import represents one uploaded CSV file moving through the pipeline.
#
# Progress counters are *derived* from the database (COUNT of persisted rows
# and errors), never accumulated with increments. That makes progress
# reporting safe under Sidekiq's at-least-once delivery: a retried batch job
# recomputes the same numbers instead of double-counting.
class Import < ApplicationRecord
  BATCH_SIZE = 100

  STATUSES = %w[pending processing completed completed_with_errors failed].freeze

  has_many :imported_contacts, dependent: :delete_all
  has_many :import_errors, dependent: :delete_all

  validates :filename, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }

  def file_path
    Rails.root.join("storage", "imports", "#{id}.csv")
  end

  def batch_count
    return 0 if total_rows.zero?

    (total_rows / BATCH_SIZE.to_f).ceil
  end

  def progress_percentage
    return 0 if total_rows.zero?

    (((processed_rows + failed_rows) / total_rows.to_f) * 100).round
  end

  def finished?
    status.in?(%w[completed completed_with_errors failed])
  end

  # Recompute counters from persisted data, then finalize the status when
  # every row is accounted for. Row-locked so concurrent batch jobs finishing
  # at the same time can't both read stale counts and miss the finish line.
  def refresh_progress!
    with_lock do
      self.processed_rows = imported_contacts.count
      self.failed_rows = import_errors.count

      if total_rows.positive? && processed_rows + failed_rows >= total_rows
        self.status = failed_rows.zero? ? "completed" : "completed_with_errors"
      end

      save!
    end

    broadcast_progress
  end

  def broadcast_progress
    broadcast_replace_to self, target: "import_#{id}_progress",
                               partial: "imports/progress", locals: { import: self }
  end
end
