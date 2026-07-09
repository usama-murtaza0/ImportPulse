# Processes one batch of CSV rows. Designed to be safe under Sidekiq's
# at-least-once delivery:
#
#   * Idempotent writes — successful rows and failures are upserted against a
#     unique (import_id, row_number) index, so a retried batch re-writes the
#     same rows instead of duplicating them.
#   * Self-contained arguments — the job re-reads its slice of the CSV from
#     disk using (import_id, batch_number) alone. No state is passed through
#     Redis beyond two integers.
#   * Derived progress — counters are recomputed from the database after each
#     batch (see Import#refresh_progress!), never incremented, so a retry
#     cannot double-count.
class ImportBatchJob
  include Sidekiq::Job

  sidekiq_options queue: "imports", retry: 5

  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\z/

  def perform(import_id, batch_number)
    import = Import.find(import_id)
    return if import.finished?

    contacts, errors = process_rows(import, batch_number)

    ImportedContact.upsert_all(contacts, unique_by: %i[import_id row_number]) if contacts.any?
    ImportError.upsert_all(errors, unique_by: %i[import_id row_number]) if errors.any?

    import.refresh_progress!
    broadcast_new_errors(import, errors)
  end

  private

  def process_rows(import, batch_number)
    contacts = []
    errors = []
    now = Time.current

    each_row_in_batch(import, batch_number) do |row, row_number|
      name = row["name"].to_s.strip
      email = row["email"].to_s.strip.downcase

      if name.blank?
        errors << error_attrs(import, row_number, "Name is missing", row, now)
      elsif email.blank?
        errors << error_attrs(import, row_number, "Email is missing", row, now)
      elsif !email.match?(EMAIL_FORMAT)
        errors << error_attrs(import, row_number, "Email is not a valid address", row, now)
      else
        contacts << { import_id: import.id, row_number: row_number, name: name,
                      email: email, created_at: now, updated_at: now }
      end
    end

    [contacts, errors]
  end

  def each_row_in_batch(import, batch_number)
    offset = batch_number * Import::BATCH_SIZE

    CSV.foreach(import.file_path, headers: true).each_with_index do |row, index|
      next if index < offset
      break if index >= offset + Import::BATCH_SIZE

      # +2 => 1-based line numbers, plus the header row
      yield row, index + 2
    end
  end

  def error_attrs(import, row_number, message, row, now)
    { import_id: import.id, row_number: row_number, message: message,
      raw_data: row.to_h.to_json, created_at: now, updated_at: now }
  end

  def broadcast_new_errors(import, errors)
    return if errors.empty?

    import.import_errors.where(row_number: errors.map { |e| e[:row_number] }).find_each do |error|
      Turbo::StreamsChannel.broadcast_append_to(
        import, target: "import_#{import.id}_errors",
                partial: "imports/error_row", locals: { import_error: error }
      )
    end
  end
end
