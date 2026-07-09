# Counts data rows in a CSV file without loading it into memory.
module CsvRowCounter
  module_function

  def count(path)
    count = 0
    CSV.foreach(path, headers: true) { count += 1 }
    count
  end
end
