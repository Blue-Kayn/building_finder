#!/usr/bin/env ruby
require_relative 'building_extractor_functions'

# Extract building names from Airbnb listings

INPUT_CSV = "palm_jumeirah_data.csv"
OUTPUT_CSV = "palm_jumeirah_with_buildings.csv"
VILLAS_CSV = "palm_jumeirah_villas.csv"
VILLA_IDS_FILE = "villa_ids.txt"
BROKEN_LINKS_FILE = "broken_airbnb_links.txt"

# Load previously identified villa IDs to skip them
known_villa_ids = Set.new
if File.exist?(VILLA_IDS_FILE)
  File.readlines(VILLA_IDS_FILE).each { |line| known_villa_ids.add(line.strip) }
  puts "Loaded #{known_villa_ids.size} known villa IDs from previous runs"
end

# Load previously identified broken links to skip them
broken_link_ids = Set.new
if File.exist?(BROKEN_LINKS_FILE)
  File.readlines(BROKEN_LINKS_FILE).each { |line| broken_link_ids.add(line.strip) }
  puts "Loaded #{broken_link_ids.size} known broken links from previous runs"
end

options = Selenium::WebDriver::Chrome::Options.new

# Create a new profile directory specifically for this script
profile_dir = File.join(Dir.pwd, 'airbnb_extractor_profile')
FileUtils.mkdir_p(profile_dir)

options.add_argument("--user-data-dir=#{profile_dir}")
options.add_argument("--window-size=1920,1080")
options.add_argument("--disable-blink-features=AutomationControlled")
options.add_argument("--disable-dev-shm-usage")

# Add a real user agent
options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

# Set Chrome options to avoid detection
prefs = {
  excludeSwitches: ["enable-automation"],
  useAutomationExtension: false
}
options.add_preference(:excludeSwitches, ["enable-automation"])
options.add_preference(:useAutomationExtension, false)

driver = Selenium::WebDriver.for :chrome, options: options

# Remove webdriver property
driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")

# Main output CSV - apartments only
CSV.open(OUTPUT_CSV, 'w') do |csv|
  csv << ['Airbnb ID', 'Airbnb URL', 'Building Name', 'Latitude', 'Longitude', 'Confidence', 'Method', 
          'Revenue Potential', 'Days Available', 'Annual Revenue', 'Occupancy', 'Daily Rate', 'Bedrooms']
end

# Separate CSV for villas
CSV.open(VILLAS_CSV, 'w') do |csv|
  csv << ['Airbnb ID', 'Airbnb URL', 'Building Name', 'Latitude', 'Longitude', 'Confidence', 'Method', 
          'Revenue Potential', 'Days Available', 'Annual Revenue', 'Occupancy', 'Daily Rate', 'Bedrooms']
end

count = 0
processed = 0
apartments_count = 0
villas_count = 0
broken_links_count = 0

CSV.foreach(INPUT_CSV, headers: true) do |row|
  count += 1
  airbnb_id = row['Airbnb ID']
  airbnb_url = row['Airbnb URL']
  
  # Skip if we already know this is a villa from previous runs
  if known_villa_ids.include?(airbnb_id)
    puts "\n[#{count}] #{airbnb_id} - VILLA (cached, adding to villas CSV)"
    CSV.open(VILLAS_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, 'VILLA', nil, nil, nil, 'manual',
              row['Revenue Potential'], row['Days Available'], 
              row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
    end
    villas_count += 1
    next
  end
  
  # Skip if we already know this link is broken from previous runs
  if broken_link_ids.include?(airbnb_id)
    puts "\n[#{count}] #{airbnb_id} - BROKEN LINK (cached, skipping - not saved)"
    broken_links_count += 1
    next
  end
  
  # Skip rows without Airbnb URL
  unless airbnb_url && airbnb_url.start_with?('http')
    next
  end
  
  begin
    puts "\n[#{count}/#{processed}] #{airbnb_id}"
    
    driver.get(airbnb_url)
    sleep(8)  # Wait longer for JavaScript to fully execute
    
    # Force page to fully render by scrolling
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    sleep(2)
    driver.execute_script("window.scrollTo(0, 0);")
    sleep(1)
    # Check if we landed on a 404 page
    if driver.current_url.include?('/404') || driver.page_source.include?('Page not found')
      puts "  ❌ 404 - Listing no longer exists, skipping (not saved)"
      
      # Save this broken link ID for future runs
      File.open(BROKEN_LINKS_FILE, 'a') { |f| f.puts(airbnb_id) }
      broken_link_ids.add(airbnb_id)
      broken_links_count += 1
      
      processed += 1
      next
    end
    
    doc = Nokogiri::HTML(driver.page_source)
    
    # Extract title, description, and location
    title = doc.css('h1').first&.text&.strip || ""
    description = doc.css('[data-section-id="DESCRIPTION_DEFAULT"]').first&.text&.strip || ""
    location = doc.css('div[data-section-id="LOCATION_DEFAULT"]').first&.text&.strip || ""
    
    # Search ALL text for building names (but smart about context)
    full_text = "#{title}\n#{description}\n#{location}"
    
    puts "  Title: #{title[0..60]}"
    puts "  Description preview: #{description[0..100]}..." if description.length > 0
    
    # Check if this is a villa first (based on BOTH property type AND title)
    if is_villa?(doc, title)
      puts "  🏡 Detected VILLA - saving to villas CSV"
      
      # Save this villa ID for future runs
      File.open(VILLA_IDS_FILE, 'a') { |f| f.puts(airbnb_id) }
      known_villa_ids.add(airbnb_id)
      
      CSV.open(VILLAS_CSV, 'a') do |csv|
        csv << [airbnb_id, airbnb_url, 'VILLA', nil, nil, nil, 'manual',
                row['Revenue Potential'], row['Days Available'], 
                row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
      end
      villas_count += 1
      processed += 1
      next
    else
      # Not a villa - try to find building name
      building, confidence = extract_building_from_text(full_text)
      method = 'text'
      
      if building
        driver.execute_script("return document.readyState") == "complete"
        
        # Extract coordinates from listing
        listing_lat, listing_lng = extract_coordinates(driver)
        # Extract coordinates from listing
        listing_lat, listing_lng = extract_coordinates(driver)
        
        if listing_lat && listing_lng
          puts "  📍 Listing coordinates: #{listing_lat}, #{listing_lng}"
          
          # Get official building coordinates
          official_coords = get_building_coordinates(building)
          
          if official_coords
            distance = calculate_distance(listing_lat, listing_lng, official_coords[0], official_coords[1])
            puts "  📏 Distance from #{building}: #{distance.round}m"
            
            # If more than 500m away, mark as manual
            if distance > 500
              puts "  ⚠️ Distance >500m - marking as MANUAL (likely wrong building)"
              CSV.open(OUTPUT_CSV, 'a') do |csv|
                csv << [airbnb_id, airbnb_url, building, listing_lat, listing_lng, nil, 'manual_distance_check',
                        row['Revenue Potential'], row['Days Available'], 
                        row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
              end
            else
              # Distance validation passed
              puts "  ✓ Building: #{building} (#{confidence}) - validated by distance (#{distance.round}m)"
              
              # Special case: Atlantis is extremely rare, default to manual
              if building.match?(/ATLANTIS/i)
                puts "  ⚠ ATLANTIS - defaulting to manual (extremely rare for STR)"
                CSV.open(OUTPUT_CSV, 'a') do |csv|
                  csv << [airbnb_id, airbnb_url, 'ATLANTIS', listing_lat, listing_lng, nil, 'manual',
                          row['Revenue Potential'], row['Days Available'], 
                          row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
                end
              else
                CSV.open(OUTPUT_CSV, 'a') do |csv|
                  csv << [airbnb_id, airbnb_url, building, listing_lat, listing_lng, confidence, method,
                          row['Revenue Potential'], row['Days Available'], 
                          row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
                end
              end
            end
          else
            # No official coords for this building - save without validation
            puts "  ✓ Building: #{building} (#{confidence}) - no validation coords available"
            CSV.open(OUTPUT_CSV, 'a') do |csv|
              csv << [airbnb_id, airbnb_url, building, listing_lat, listing_lng, confidence, method,
                      row['Revenue Potential'], row['Days Available'], 
                      row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
            end
          end
        else
          # Couldn't extract coordinates - save building name anyway
          puts "  ✓ Building: #{building} (#{confidence}) - no coords extracted"
          CSV.open(OUTPUT_CSV, 'a') do |csv|
            csv << [airbnb_id, airbnb_url, building, nil, nil, confidence, method,
                    row['Revenue Potential'], row['Days Available'], 
                    row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
          end
        end
      else
        puts "  ✗ No building name found in text"
        CSV.open(OUTPUT_CSV, 'a') do |csv|
          csv << [airbnb_id, airbnb_url, nil, nil, nil, nil, 'no_building_found',
                  row['Revenue Potential'], row['Days Available'], 
                  row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
        end
      end
      
      apartments_count += 1
    end
    
    processed += 1
    sleep(2)
    
  rescue => e
    puts "  ERROR: #{e.message}"
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, nil, nil, nil, nil, 'error',
              row['Revenue Potential'], row['Days Available'], 
              row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
    end
  end
end

puts "\n" + "="*60
puts "Processing Complete!"
puts "="*60
puts "Total listings processed: #{processed}"
puts "Apartments saved to #{OUTPUT_CSV}: #{apartments_count}"
puts "Villas saved to #{VILLAS_CSV}: #{villas_count}"
puts "Broken links (not saved): #{broken_links_count}"
puts "="*60
puts "\nNext steps:"
puts "1. Review apartments in: #{OUTPUT_CSV}"
puts "2. Review villas separately in: #{VILLAS_CSV}"
puts "3. Broken links are cached in #{BROKEN_LINKS_FILE} and excluded from output"
puts "="*60

driver.quit