module CsvHelpers
  # Builds CSV content with `count` valid rows.
  def valid_csv(count)
    rows = (1..count).map { |i| "Person #{i},person#{i}@example.com" }
    "name,email\n#{rows.join("\n")}\n"
  end
end

RSpec.configure do |config|
  config.include CsvHelpers
end
