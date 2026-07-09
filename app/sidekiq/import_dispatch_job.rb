# Fans an import out into fixed-size batches.
#
# Deliberately does almost nothing itself: it counts rows, records the total,
# and enqueues one ImportBatchJob per batch. Small dispatch jobs keep the
# fan-out cheap to retry — if this job runs twice, the batch jobs it enqueues
# are themselves idempotent, so the worst case is wasted work, not bad data.
class ImportDispatchJob
  include Sidekiq::Job

  sidekiq_options queue: "imports", retry: 5

  def perform(import_id)
    import = Import.find(import_id)
    return if import.finished?

    total = CsvRowCounter.count(import.file_path)

    import.update!(total_rows: total, status: "processing")
    import.broadcast_progress

    if total.zero?
      import.update!(status: "completed")
      import.broadcast_progress
      return
    end

    import.batch_count.times do |batch_number|
      ImportBatchJob.perform_async(import.id, batch_number)
    end
  end
end
