#!/usr/bin/env ruby
require 'csv'

# Configuration
INPUT_FILE = "palm_with_buildings.csv"
OUTPUT_FILE = "palm_buildings_with_names_only.csv"

# Statistics
total_rows = 0
rows_with_building = 0

puts "="*60
puts "Filtering rows with Building Names"
puts "Input: #{INPUT_FILE}"
puts "Output: #{OUTPUT_FILE}"
puts "="*60
puts ""

CSV.open(OUTPUT_FILE, 'w') do |output|
  first_row = true
  
  CSV.foreach(INPUT_FILE, headers: true) do |row|
    total_rows += 1
    
    # Write headers on first row
    if first_row
      # Add new "Airbnb Link" column to headers
      headers = row.headers + ['Airbnb Link']
      output << headers
      first_row = false
    end
    
    # Filter: only rows with non-empty Building Name
    building_name = row['Building Name']
    next if building_name.nil? || building_name.strip.empty?
    
    rows_with_building += 1
    
    # Create Airbnb link from ID
    airbnb_id = row['AirBnB ID']
    airbnb_link = airbnb_id && !airbnb_id.strip.empty? ? "https://www.airbnb.co.uk/rooms/#{airbnb_id}" : ""
    
    # Write the entire row with the new Airbnb Link column
    output << (row.fields + [airbnb_link])
  end
end

puts "\nResults:"
puts "-" * 60
puts "Total rows processed: #{total_rows}"
puts "Rows with building names: #{rows_with_building}"
puts "Rows filtered out: #{total_rows - rows_with_building}"
puts "="*60
puts "Done! Check #{OUTPUT_FILE}"