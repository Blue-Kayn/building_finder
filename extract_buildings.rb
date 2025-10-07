#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'nokogiri'
require 'csv'
require 'fileutils'

# Configuration
INPUT_FILE = "THE FINAL PALM FILE 180+ - payload.listings.csv.csv"
OUTPUT_CSV = "palm_with_buildings.csv"
BROKEN_LINKS_FILE = "broken_links.txt"
VILLA_IDS_FILE = "villa_ids.txt"

# Load cached villas
known_villa_ids = Set.new
if File.exist?(VILLA_IDS_FILE)
  File.readlines(VILLA_IDS_FILE).each { |line| known_villa_ids.add(line.strip) }
  puts "Loaded #{known_villa_ids.size} known villa IDs"
end

# Load cached broken links
broken_link_ids = Set.new
if File.exist?(BROKEN_LINKS_FILE)
  File.readlines(BROKEN_LINKS_FILE).each { |line| broken_link_ids.add(line.strip) }
  puts "Loaded #{broken_link_ids.size} known broken links"
end

# Setup Selenium
options = Selenium::WebDriver::Chrome::Options.new
profile_dir = File.join(Dir.pwd, 'chrome_profile')
FileUtils.mkdir_p(profile_dir)

options.add_argument("--user-data-dir=#{profile_dir}")
options.add_argument("--window-size=1920,1080")
options.add_argument("--disable-blink-features=AutomationControlled")
options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

driver = Selenium::WebDriver.for :chrome, options: options
driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")

# Load helper functions
require_relative 'building_helpers'

# Create output CSV
CSV.open(OUTPUT_CSV, 'w') do |csv|
  csv << ['AirBnB ID', 'Bedrooms', 'Bathrooms', 'Revenue', 'Occupancy Rate', 'ADR', 
          'Days Available', 'Lat', 'Lng', 'Building Name', 'Unit Type', 'Distance (m)', 
          'Confidence', 'Status']
end

count = 0
processed = 0
apartments_count = 0
villas_count = 0
broken_count = 0

# Process CSV
CSV.foreach(INPUT_FILE, headers: true) do |row|
  count += 1
  
  airbnb_id = row['AirBnB ID'].to_s.strip
  bedrooms = row['Bedrooms']
  bathrooms = row['Bathrooms']
  revenue = row['Revenue']
  occupancy_rate = row['Occupancy Rate']
  adr = row['ADR']
  days_available = row['Days Available']
  csv_lat = row['Lat'].to_f
  csv_lng = row['Lng'].to_f
  
  # Skip if cached as villa
  if known_villa_ids.include?(airbnb_id)
    puts "\n[#{count}] #{airbnb_id} - VILLA (cached, skipping)"
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, bedrooms, bathrooms, revenue, occupancy_rate, adr, 
              days_available, csv_lat, csv_lng, nil, 'Villa', nil, nil, 'cached_villa']
    end
    villas_count += 1
    next
  end
  
  # Skip if cached as broken
  if broken_link_ids.include?(airbnb_id)
    puts "\n[#{count}] #{airbnb_id} - BROKEN (cached, skipping)"
    broken_count += 1
    next
  end
  
  # Construct Airbnb URL
  airbnb_url = "https://www.airbnb.com/rooms/#{airbnb_id}"
  
  begin
    puts "\n[#{count}] #{airbnb_id}"
    puts "  Coords: #{csv_lat}, #{csv_lng}"
    
    driver.get(airbnb_url)
    sleep(8)
    
    # Check for 404
    if driver.current_url.include?('/404') || driver.page_source.include?('Page not found')
      puts "  ❌ 404 - Skipping"
      File.open(BROKEN_LINKS_FILE, 'a') { |f| f.puts(airbnb_id) }
      broken_link_ids.add(airbnb_id)
      broken_count += 1
      processed += 1
      next
    end
    
    doc = Nokogiri::HTML(driver.page_source)
    
    # Extract text
    title = doc.css('h1').first&.text&.strip || ""
    description = doc.css('[data-section-id="DESCRIPTION_DEFAULT"]').first&.text&.strip || ""
    location = doc.css('div[data-section-id="LOCATION_DEFAULT"]').first&.text&.strip || ""
    full_text = "#{title}\n#{description}\n#{location}"
    
    puts "  Title: #{title[0..60]}"
    
    # Check if villa
    if is_villa?(doc, title)
      puts "  🏡 VILLA"
      File.open(VILLA_IDS_FILE, 'a') { |f| f.puts(airbnb_id) }
      known_villa_ids.add(airbnb_id)
      
      CSV.open(OUTPUT_CSV, 'a') do |csv|
        csv << [airbnb_id, bedrooms, bathrooms, revenue, occupancy_rate, adr, 
                days_available, csv_lat, csv_lng, nil, 'Villa', nil, nil, 'villa']
      end
      villas_count += 1
    else
      # Extract building name for apartments
      building, confidence = extract_building_from_text(full_text)
      
      if building
        # Validate with coordinates
        official_coords = get_building_coordinates(building)
        
        if official_coords
          distance = calculate_distance(csv_lat, csv_lng, official_coords[0], official_coords[1])
          puts "  📏 Distance from #{building}: #{distance.round}m"
          
          if distance > 500
            puts "  ⚠️ Distance >500m - MANUAL CHECK"
            status = 'manual_check'
          else
            puts "  ✓ #{building} (#{confidence}) - validated #{distance.round}m"
            status = 'validated'
          end
          
          CSV.open(OUTPUT_CSV, 'a') do |csv|
            csv << [airbnb_id, bedrooms, bathrooms, revenue, occupancy_rate, adr, 
                    days_available, csv_lat, csv_lng, building, 'Apartment', 
                    distance.round, confidence, status]
          end
        else
          puts "  ✓ #{building} (#{confidence}) - no coords to validate"
          CSV.open(OUTPUT_CSV, 'a') do |csv|
            csv << [airbnb_id, bedrooms, bathrooms, revenue, occupancy_rate, adr, 
                    days_available, csv_lat, csv_lng, building, 'Apartment', 
                    nil, confidence, 'text_only']
          end
        end
      else
        puts "  ✗ No building name found"
        CSV.open(OUTPUT_CSV, 'a') do |csv|
          csv << [airbnb_id, bedrooms, bathrooms, revenue, occupancy_rate, adr, 
                  days_available, csv_lat, csv_lng, nil, 'Apartment', 
                  nil, nil, 'not_found']
        end
      end
      
      apartments_count += 1
    end
    
    processed += 1
    sleep(2)
    
  rescue => e
    puts "  ERROR: #{e.message}"
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, bedrooms, bathrooms, revenue, occupancy_rate, adr, 
              days_available, csv_lat, csv_lng, nil, nil, nil, nil, 'error']
    end
  end
end

puts "\n" + "="*60
puts "Complete!"
puts "="*60
puts "Processed: #{processed}"
puts "Apartments: #{apartments_count}"
puts "Villas: #{villas_count}"
puts "Broken/Skipped: #{broken_count}"
puts "="*60

driver.quit