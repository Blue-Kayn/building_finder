#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'nokogiri'
require 'csv'
require 'fileutils'
require 'net/http'
require 'uri'

# Extract building names from Airbnb using text + image analysis

INPUT_CSV = "palm_jumeirah_data.csv"
OUTPUT_CSV = "palm_jumeirah_with_buildings.csv"
IMAGES_DIR = "airbnb_images"
VILLA_IDS_FILE = "villa_ids.txt"
BROKEN_LINKS_FILE = "broken_airbnb_links.txt"

FileUtils.mkdir_p(IMAGES_DIR)

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
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--disable-gpu")
options.add_argument("--disable-software-rasterizer")
options.add_argument("--disable-extensions")
driver = Selenium::WebDriver.for :chrome, options: options

CSV.open(OUTPUT_CSV, 'w') do |csv|
  csv << ['Airbnb ID', 'Airbnb URL', 'Building Name', 'Latitude', 'Longitude', 'Confidence', 'Method', 
          'Revenue Potential', 'Days Available', 'Annual Revenue', 'Occupancy', 'Daily Rate', 'Bedrooms']
end

def is_villa?(doc, title)
  # Check BOTH the property type subtitle AND the title for villa indicators
  
  # First check the "Entire X in Dubai" subtitle
  property_type_element = doc.css('h2').find { |h2| h2.text.match?(/Entire .+ in Dubai/i) }
  
  property_type_from_subtitle = false
  if property_type_element
    property_type_text = property_type_element.text
    puts "    Property type: #{property_type_text}"
    
    # If subtitle says villa/townhouse/home - it's a villa
    property_type_from_subtitle = property_type_text.match?(/Entire\s+(villa|townhouse|vacation\s+home|home|house)\s+in/i)
  end
  
  # Also check the title for villa indicators
  villa_in_title = title.match?(/\b(villa|townhouse|beach\s+house)\b/i)
  
  # If EITHER the subtitle OR title indicates villa, mark it as villa
  if property_type_from_subtitle || villa_in_title
    if property_type_from_subtitle && villa_in_title
      puts "    ✓ Villa confirmed by BOTH subtitle and title"
    elsif villa_in_title
      puts "    ✓ Villa detected in title (even though subtitle might say 'rental unit')"
    else
      puts "    ✓ Villa detected in subtitle"
    end
    return true
  end
  
  false
end

def extract_coordinates(driver)
  # Try to extract lat/long from the page
  begin
    page_source = driver.page_source
    
    # Debug: Save a sample page to inspect (only first time)
    if !File.exist?('debug_page_sample.html')
      File.write('debug_page_sample.html', page_source)
      puts "    [DEBUG] Saved page source to debug_page_sample.html for inspection"
    end
    
    # Try multiple patterns where Airbnb might store coordinates
    patterns = [
      # Pattern 1: "latitude":25.1234,"longitude":55.4321
      [/"latitude"\s*:\s*([0-9.-]+)/i, /"longitude"\s*:\s*([0-9.-]+)/i],
      # Pattern 2: "lat":25.1234,"lng":55.4321
      [/"lat"\s*:\s*([0-9.-]+)/i, /"lng"\s*:\s*([0-9.-]+)/i],
      # Pattern 3: lat:25.1234,lng:55.4321 (without quotes)
      [/[^"]lat\s*:\s*([0-9.-]+)/i, /[^"]lng\s*:\s*([0-9.-]+)/i],
      # Pattern 4: "lat":25.1234,"lon":55.4321
      [/"lat"\s*:\s*([0-9.-]+)/i, /"lon"\s*:\s*([0-9.-]+)/i],
      # Pattern 5: latitude=25.1234 or similar
      [/latitude[=:]\s*([0-9.-]+)/i, /longitude[=:]\s*([0-9.-]+)/i]
    ]
    
    patterns.each_with_index do |(lat_pattern, lng_pattern), idx|
      lat_match = page_source.match(lat_pattern)
      lng_match = page_source.match(lng_pattern)
      
      if lat_match && lng_match
        lat = lat_match[1].to_f
        lng = lng_match[1].to_f
        
        # Sanity check - Dubai coordinates should be roughly 25.x, 55.x
        if lat > 24.5 && lat < 25.5 && lng > 54.5 && lng < 56.0
          puts "    ✓ Extracted coords using pattern #{idx + 1}"
          return [lat, lng]
        else
          puts "    ⚠ Found coords (#{lat}, #{lng}) but outside Dubai range"
        end
      end
    end
    
    puts "    ⚠ Could not extract valid coordinates from page"
  rescue => e
    puts "    Failed to extract coordinates: #{e.message}"
  end
  
  [nil, nil]
end

def calculate_distance(lat1, lon1, lat2, lon2)
  # Haversine formula to calculate distance between two points in meters
  return nil if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?
  
  rad_per_deg = Math::PI / 180
  earth_radius = 6371000 # meters
  
  dlat = (lat2 - lat1) * rad_per_deg
  dlon = (lon2 - lon1) * rad_per_deg
  
  a = Math.sin(dlat / 2) ** 2 + Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) * Math.sin(dlon / 2) ** 2
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  
  earth_radius * c
end

def get_building_coordinates(building_name)
  # Official building coordinates from your data
  building_coords = {
    'ATLANTIS THE PALM' => [25.130481, 55.117161],
    'ATLANTIS' => [25.130481, 55.117161],
    'ROYAL ATLANTIS' => [25.1265, 55.1169],
    'BALQIS RESIDENCES' => [25.1180, 55.1220],
    'BALQIS RESIDENCE' => [25.1180, 55.1220],
    'FIVE PALM' => [25.118372, 55.132879],
    'FIVE AT PALM JUMEIRAH' => [25.118372, 55.132879],
    'THE 8' => [25.118075, 55.109729],
    'THE PALM TOWER' => [25.1128, 55.1386],
    'PALM TOWER' => [25.1128, 55.1386],
    'ONE PALM' => [25.1170, 55.1355],
    'ONE AT PALM JUMEIRAH' => [25.1170, 55.1355],
    'OCEANA' => [25.1189, 55.1318],
    'OCEANA RESIDENCES' => [25.1189, 55.1318],
    'OCEANA HOTEL' => [25.1189, 55.1318],
    'OCEANA APARTMENTS' => [25.1189, 55.1318],
    'ADRIATIC' => [25.1189, 55.1318],
    'PACIFIC' => [25.1189, 55.1318],
    'CARIBBEAN' => [25.1189, 55.1318],
    'ATLANTIC' => [25.1189, 55.1318],
    'AEGEAN' => [25.1189, 55.1318],
    'BALTIC' => [25.1189, 55.1318],
    'SOUTHERN' => [25.1189, 55.1318],
    'SHORELINE' => [25.1185, 55.1305],
    'SHORELINE APARTMENTS' => [25.1185, 55.1305],
    'GOLDEN MILE' => [25.10984, 55.143428],
    'GOLDEN MILE 1' => [25.10984, 55.143428],
    'GOLDEN MILE 2' => [25.10984, 55.143428],
    'GOLDEN MILE 3' => [25.10984, 55.143428],
    'GOLDEN MILE 4' => [25.10984, 55.143428],
    'GOLDEN MILE 5' => [25.10984, 55.143428],
    'GOLDEN MILE 6' => [25.10984, 55.143428],
    'FAIRMONT PALM' => [25.1269, 55.1298],
    'FAIRMONT' => [25.1269, 55.1298],
    'RAFFLES PALM' => [25.1275, 55.1215],
    'RAFFLES THE PALM' => [25.1275, 55.1215],
    'W DUBAI' => [25.1175, 55.1225],
    'W PALM' => [25.1175, 55.1225],
    'W RESIDENCES' => [25.1175, 55.1225],
    'DUKES PALM' => [25.1258, 55.1230],
    'RIXOS' => [25.1225, 55.1235], # Using Radisson coords as approx
    'RIXOS PALM' => [25.1225, 55.1235]
  }
  
  building_coords[building_name.upcase]
end

def extract_building_from_text(text)
  return [nil, nil] if text.nil? || text.empty?
  
  # Base building names from Palm Jumeirah
  base_buildings = [
    'THE PALM TOWER', 'PALM TOWER',
    'FIVE AT PALM JUMEIRAH', 'FIVE PALM', 'FIVE',
    'AZIZI MINA', 'MINA',
    'AZURE RESIDENCES', 'AZURE',
    'BALQIS RESIDENCE', 'BALQIS',
    'KEMPINSKI RESIDENCES', 'KEMPINSKI PALM', 'KEMPINSKI',
    'ONE AT PALM JUMEIRAH', 'ONE PALM',
    'OCEANA', 'OCEANA RESIDENCES', 'OCEANA HOTEL', 'OCEANA APARTMENTS',
    'ROYAL ATLANTIS', 'ATLANTIS THE PALM', 'ATLANTIS',
    'PALM VIEWS EAST', 'PALM VIEWS WEST', 'PALM VIEWS',
    'PALM BEACH TOWERS', 'PALM BEACH',
    'GOLDEN MILE',
    'CLUB VISTA MARE', 'VISTA MARE',
    'SERENIA RESIDENCES', 'SERENIA LIVING', 'SERENIA',
    'SEVEN HOTEL', 'SEVEN PALM',
    'SLS AT PALM JUMEIRAH', 'SLS PALM', 'SLS',
    'W RESIDENCES', 'W DUBAI', 'W PALM',
    'RAFFLES THE PALM', 'RAFFLES PALM', 'RAFFLES',
    'FAIRMONT PALM', 'FAIRMONT',
    'ANANTARA PALM', 'ANANTARA',
    'RIXOS PALM', 'RIXOS',
    'TIARA RESIDENCES', 'TIARA',
    'GRANDUER RESIDENCES', 'GRANDUER',
    'ROYAL AMWAJ RESIDENCES', 'ROYAL AMWAJ',
    'ROYAL BAY',
    'OCEAN HOUSE',
    'PALME COUTURE',
    'THE 8',
    'LUCE',
    'ARMANI BEACH RESIDENCES', 'ARMANI BEACH', 'ARMANI PALM',
    'AVA AT PALM JUMEIRAH', 'AVA PALM', 'AVA',
    'COMO RESIDENCES', 'COMO',
    'ELLINGTON BEACH HOUSE', 'ELLINGTON BEACH', 'ELLINGTON',
    'MURABA RESIDENCES', 'MURABA',
    'ORLA BY OMNIYAT', 'ORLA INFINITY', 'ORLA',
    'SIX SENSES RESIDENCES', 'SIX SENSES PALM', 'SIX SENSES',
    'DREAM PALM', 'DREAM',
    'ONE CRESCENT',
    'THE ALEF RESIDENCES', 'ALEF RESIDENCES', 'ALEF',
    'XXII CARAT', '22 CARAT',
    'SHORELINE', 'SHORELINE APARTMENTS',
    'MARINA RESIDENCES',
    'EMAAR BEACHFRONT', 'MARINA VISTA', 'BEACH ISLE', 'BEACH VISTA', 
    'SUNRISE BAY', 'GRAND BLEU', 'PALACE BEACH RESIDENCE', 'PALACE BEACH',
    'AL TAMR', 'TAMR',
    'AL HAMRI', 'HAMRI',
    'AL HASEER', 'HASEER',
    'AL NABAT', 'NABAT',
    'AL SARROOD', 'SARROOD',
    'AL HABOOL', 'HABOOL',
    'AL BASHRI', 'BASHRI', 'AL BASRI', 'BASRI',
    'AL DABAS', 'DABAS',
    'AL ANBARA', 'ANBARA',
    'AL HALLAWI', 'HALLAWI',
    'AL HATIMI', 'HATIMI',
    'AL KHUDRAWI', 'KHUDRAWI',
    'AL KHUSHKAR', 'KHUSHKAR',
    'AL MSALLI', 'MSALLI',
    'AL SHAHLA', 'SHAHLA',
    'AL SULTANA', 'SULTANA',
    'JASH HAMAD', 'JASH FALQA',
    'ABU KEIBAL',
    'ADRIATIC', 'AEGEAN', 'ATLANTIC', 'AQUAMARINE',
    'BALTIC', 'CARIBBEAN', 'PACIFIC', 'SOUTHERN',
    'DIAMOND', 'EMERALD', 'RUBY', 'TANZANITE'
  ]
  
  # Sort by length (longest first) to match more specific names before generic ones
  known_buildings = base_buildings.sort_by { |b| -b.length }
  
  # Create exclusion patterns - phrases that indicate it's NOT in the building
  exclusion_phrases = [
    /view(?:s)?\s+(?:of|over|to|towards|across|onto)\s+/i,
    /overlooking\s+(?:the\s+)?/i,
    /facing\s+(?:the\s+)?/i,
    /close\s+(?:proximity\s+)?to\s+/i,
    /near\s+(?:to\s+)?(?:the\s+)?/i,
    /nearby\s+(?:the\s+)?/i,
    /walking\s+distance\s+(?:to|from)\s+/i,
    /minutes?\s+(?:from|to|away|walk)\s+/i,
    /proximity\s+to\s+/i,
    /access\s+to\s+/i,
    /next\s+to\s+/i,
    /opposite\s+/i,
    /across\s+from\s+/i,
    /short\s+(?:walk|drive|distance)\s+(?:to|from)\s+/i,
    /perfect\s+for\s+visiting\s+/i,
    /explore\s+/i,
    /visit\s+/i,
    /iconic\s+/i
  ]
  
  patterns = [
    # ABSOLUTE HIGHEST PRIORITY - Explicit location statements with key buildings
    {regex: /\b(?:FIVE\s+(?:AT\s+)?PALM\s+JUMEIRAH|FIVE\s+PALM)\s+is\s+/i, confidence: 'high', priority: 0},
    {regex: /\bparties\s+at\s+(?:the\s+)?(FIVE)\b/i, confidence: 'high', priority: 0},
    {regex: /\blocated\s+(?:in|at)\s+(?:the\s+)?(FIVE\s+(?:AT\s+)?PALM\s+JUMEIRAH|FIVE\s+PALM)\b/i, confidence: 'high', priority: 0},
    
    # HIGHEST priority - "Located in/at" with exact building names
    *known_buildings.map { |b| 
      {regex: /\b(?:located|situated|based|residing|apartment|unit|flat|penthouse|studio)\s+(?:in|at|within)\s+(?:the\s+)?(#{Regexp.escape(b)})\b/i, confidence: 'high', priority: 1}
    },
    
    # VERY HIGH priority - Building name is a complete sentence or at end
    *known_buildings.map { |b| 
      {regex: /\b(#{Regexp.escape(b)})\s+is\s+(?:an|a|the)/i, confidence: 'high', priority: 1}
    },
    
    # HIGH confidence - Building name followed by "- Palm Jumeirah" or similar
    *known_buildings.map { |b| 
      {regex: /\b(#{Regexp.escape(b)})\s*[-–,]\s*(?:Palm\s+Jumeirah|Dubai)/i, confidence: 'high', priority: 2}
    },
    
    # HIGH confidence - Numbered variations with context
    {regex: /\b(?:in|at)\s+(GOLDEN MILE\s+\d{1,2})\b/i, confidence: 'high', priority: 1},
    {regex: /\b(?:in|at)\s+(BALQIS RESIDENCE\s+\d)\b/i, confidence: 'high', priority: 1},
    {regex: /\b(?:in|at)\s+(PALM BEACH TOWERS?[-\s]\d)\b/i, confidence: 'high', priority: 1},
    {regex: /\b(?:in|at)\s+(SERENIA (?:RESIDENCES|LIVING)\s+(?:BUILDING\s+)?[A-D]|TOWER\s+\d)\b/i, confidence: 'high', priority: 1},
    {regex: /\b(?:in|at)\s+(SEVEN HOTEL.*PALM[-\s][AB])\b/i, confidence: 'high', priority: 1},
    {regex: /\b(?:in|at)\s+(MARINA APARTMENTS\s+\d)\b/i, confidence: 'high', priority: 1},
    
    # MEDIUM confidence - Exact building name matches WITHOUT exclusion context
    *known_buildings.map { |b| 
      {regex: /\b(#{Regexp.escape(b)})\b/i, confidence: 'medium', priority: 3}
    },
    
    # MEDIUM confidence - Numbered variations standalone
    {regex: /\b(GOLDEN MILE\s+\d{1,2})\b/i, confidence: 'medium', priority: 3},
    {regex: /\b(BALQIS RESIDENCE\s+\d)\b/i, confidence: 'medium', priority: 3},
    {regex: /\b(PALM BEACH TOWERS?[-\s]\d)\b/i, confidence: 'medium', priority: 3},
    {regex: /\b(SERENIA (?:RESIDENCES|LIVING)\s+(?:BUILDING\s+)?[A-D]|TOWER\s+\d)\b/i, confidence: 'medium', priority: 3},
    {regex: /\b(GRANDUER RESIDENCES[-\s](?:MAURYA|MUGHAL))\b/i, confidence: 'medium', priority: 3},
    {regex: /\b(THE RESIDENCES\s+(?:NORTH|SOUTH))\b/i, confidence: 'medium', priority: 3},
    {regex: /\b(ROYAL AMWAJ RESIDENCES\s+(?:NORTH|SOUTH))\b/i, confidence: 'medium', priority: 3},
    {regex: /\b(AL\s+[A-Z]+[-\s]B\d{1,2})\b/i, confidence: 'medium', priority: 3},
    # Only match specific building codes, not generic "Tower X"
    {regex: /\b([BFSV][-]\d{2})\b/, confidence: 'medium', priority: 3},
    
    # Frond villas
    {regex: /\b(FROND\s+[A-Z]\s+VILLA)\b/i, confidence: 'high', priority: 2},
    
    # Generic context-based patterns (lower priority)
    {regex: /(?:located in|situated in|in the|at)\s+([A-Z][A-Za-z\s&]+(?:RESIDENCES?|TOWER|APARTMENTS?))/i, confidence: 'medium', priority: 4},
    {regex: /([A-Z][A-Za-z\s&]+(?:RESIDENCES?|TOWER|APARTMENTS?))\s+[-–]\s+PALM\s+JUMEIRAH/i, confidence: 'medium', priority: 4},
  ]
  
  # Sort by priority (lower number = higher priority)
  patterns.sort_by! { |p| p[:priority] || 999 }
  
  best_match = nil
  best_confidence = nil
  best_priority = 999
  
  patterns.each do |p|
    matches = text.to_enum(:scan, p[:regex]).map { Regexp.last_match }
    
    matches.each do |match|
      building = match[1].strip
      
      # Check if this match is in an exclusion context
      match_start = match.begin(0)
      # Look at 150 characters before the match for exclusion context
      context_before = text[[match_start - 150, 0].max...match_start]
      
      # Skip if any exclusion phrase appears right before the building name
      is_excluded = exclusion_phrases.any? { |ex| context_before.match?(ex) }
      
      if is_excluded
        puts "    ⚠ Skipping '#{building}' - found in viewing/proximity context"
        next
      end
      
      # Keep the best match (highest priority = lowest number)
      if !best_match || (p[:priority] || 999) < best_priority
        best_match = building
        best_confidence = p[:confidence]
        best_priority = p[:priority] || 999
      end
    end
  end
  
  if best_match
    # Normalize common variations
    best_match = best_match.gsub(/FIVE AT PALM JUMEIRAH/i, 'FIVE PALM')
    best_match = best_match.gsub(/ONE AT PALM JUMEIRAH/i, 'ONE PALM')
    
    # Wyndham hotels are in Balqis Residences
    if best_match.match?(/WYNDHAM/i)
      best_match = 'BALQIS RESIDENCES'
    end
    
    # Normalize all Emaar Beachfront buildings to EMAAR BEACHFRONT
    emaar_beachfront_buildings = [
      /MARINA VISTA/i,
      /BEACH ISLE/i,
      /BEACH VISTA/i,
      /SUNRISE BAY/i,
      /GRAND BLEU/i,
      /PALACE BEACH/i,
      /PALACE RESIDENCES?/i
    ]
    
    emaar_beachfront_buildings.each do |pattern|
      if best_match.match?(pattern)
        best_match = 'EMAAR BEACHFRONT'
        break
      end
    end
    
    return [best_match, best_confidence]
  end
  
  [nil, nil]
end

def download_image(url, filepath)
  uri = URI.parse(url)
  response = Net::HTTP.get_response(uri)
  File.open(filepath, 'wb') { |f| f.write(response.body) } if response.is_a?(Net::HTTPSuccess)
rescue => e
  puts "    Failed to download image: #{e.message}"
end

def get_listing_images(driver)
  images = []
  
  # Find all listing images
  img_elements = driver.find_elements(css: 'img[data-original-uri]')
  
  img_elements.first(10).each do |img| # Limit to first 10 images
    src = img.attribute('data-original-uri') || img.attribute('src')
    images << src if src && src.include?('http')
  end
  
  images.uniq
end

count = 0
processed = 0

CSV.foreach(INPUT_CSV, headers: true) do |row|
  count += 1
  airbnb_id = row['Airbnb ID']
  airbnb_url = row['Airbnb URL']
  
  # Skip if we already know this is a villa from previous runs
  if known_villa_ids.include?(airbnb_id)
    puts "\n[#{count}] #{airbnb_id} - VILLA (cached, skipping)"
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, 'VILLA', nil, nil, nil, 'manual',
              row['Revenue Potential'], row['Days Available'], 
              row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
    end
    next
  end
  
  # Skip if we already know this link is broken from previous runs
  if broken_link_ids.include?(airbnb_id)
    puts "\n[#{count}] #{airbnb_id} - BROKEN LINK (cached, skipping)"
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, nil, nil, nil, nil, '404_not_found',
              row['Revenue Potential'], row['Days Available'], 
              row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
    end
    next
  end
  
  # Skip rows without Airbnb URL
  unless airbnb_url && airbnb_url.start_with?('http')
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, nil, nil, nil, nil, nil, row['Revenue Potential'], 
              row['Days Available'], row['Annual Revenue'], row['Occupancy'], 
              row['Daily Rate'], row['Bedrooms']]
    end
    next
  end
  
  begin
    puts "\n[#{count}/#{processed}] #{airbnb_id}"
    
    driver.get(airbnb_url)
    sleep(4)
    
    # Check if we landed on a 404 page
    if driver.current_url.include?('/404') || driver.page_source.include?('Page not found')
      puts "  ❌ 404 - Listing no longer exists, skipping"
      
      # Save this broken link ID for future runs
      File.open(BROKEN_LINKS_FILE, 'a') { |f| f.puts(airbnb_id) }
      broken_link_ids.add(airbnb_id)
      
      CSV.open(OUTPUT_CSV, 'a') do |csv|
        csv << [airbnb_id, airbnb_url, nil, nil, nil, nil, '404_not_found',
                row['Revenue Potential'], row['Days Available'], 
                row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
      end
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
      puts "  🏡 Detected VILLA - skipping, needs manual processing"
      
      # Save this villa ID for future runs
      File.open(VILLA_IDS_FILE, 'a') { |f| f.puts(airbnb_id) }
      known_villa_ids.add(airbnb_id)
      
      CSV.open(OUTPUT_CSV, 'a') do |csv|
        csv << [airbnb_id, airbnb_url, 'VILLA', nil, nil, nil, 'manual',
                row['Revenue Potential'], row['Days Available'], 
                row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
      end
      processed += 1
      next
    else
      # Not a villa - try to find building name
      building, confidence = extract_building_from_text(full_text)
      method = 'text'
      
      if building
        # Extract coordinates from listing
        listing_lat, listing_lng = extract_coordinates(driver)
        
        if listing_lat && listing_lng
          puts "  📍 Listing coordinates: #{listing_lat}, #{listing_lng}"
          
          # Get official building coordinates
          official_coords = get_building_coordinates(building)
          
          if official_coords
            distance = calculate_distance(listing_lat, listing_lng, official_coords[0], official_coords[1])
            puts "  📏 Distance from #{building}: #{distance.round}m"
            
            # If more than 1000m away, mark as manual
            if distance > 1000
              puts "  ⚠️ Distance >1000m - marking as MANUAL (likely wrong building)"
              CSV.open(OUTPUT_CSV, 'a') do |csv|
                csv << [airbnb_id, airbnb_url, building, listing_lat, listing_lng, nil, 'manual_distance_check',
                        row['Revenue Potential'], row['Days Available'], 
                        row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
              end
            else
              # Distance validation passed
              puts "  ✓ Building: #{building} (#{confidence}) - validated by distance"
              
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
        puts "  ✗ No building in text, downloading images..."
        
        # Download images for OCR processing
        image_urls = get_listing_images(driver)
        image_folder = File.join(IMAGES_DIR, airbnb_id)
        FileUtils.mkdir_p(image_folder)
        
        image_urls.each_with_index do |url, idx|
          filepath = File.join(image_folder, "#{idx}.jpg")
          download_image(url, filepath)
        end
        
        puts "  Downloaded #{image_urls.length} images to #{image_folder}"
        CSV.open(OUTPUT_CSV, 'a') do |csv|
          csv << [airbnb_id, airbnb_url, nil, nil, nil, 'pending', 'needs_ocr',
                  row['Revenue Potential'], row['Days Available'], 
                  row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
        end
      end
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
puts "Phase 1 Complete: Text extraction"
puts "Processed: #{processed} listings"
puts "Output: #{OUTPUT_CSV}"
puts "Images saved to: #{IMAGES_DIR}/"
puts "\nNext: Run OCR on images in #{IMAGES_DIR}/ for listings with 'needs_ocr'"
puts "="*60

driver.quit