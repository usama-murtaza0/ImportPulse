FactoryBot.define do
  factory :import do
    filename { "contacts.csv" }
    status { "pending" }
    total_rows { 0 }
    processed_rows { 0 }
    failed_rows { 0 }

    # Writes the given CSV content to the import's expected file path.
    transient do
      csv_content { nil }
    end

    after(:create) do |import, evaluator|
      if evaluator.csv_content
        import.file_path.dirname.mkpath
        File.write(import.file_path, evaluator.csv_content)
      end
    end
  end
end
