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

FileUtils.mkdir_p(IMAGES_DIR)

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--user-data-dir=chrome_scraper_profile")
options.add_argument("--window-size=1920,1080")
driver = Selenium::WebDriver.for :chrome, options: options

CSV.open(OUTPUT_CSV, 'w') do |csv|
  csv << ['Airbnb ID', 'Airbnb URL', 'Building Name', 'Confidence', 'Method', 
          'Revenue Potential', 'Days Available', 'Annual Revenue', 'Occupancy', 'Daily Rate', 'Bedrooms']
end

def extract_building_from_text(text)
  return [nil, nil] if text.nil? || text.empty?
  
  patterns = [
    # High confidence patterns
    {regex: /(?:located in|situated in|in the)\s+([A-Z][A-Za-z\s&]+(?:Residences?|Tower|Towers?))/i, confidence: 'high'},
    {regex: /([A-Z][A-Za-z\s&]+(?:Residences?|Tower|Towers?))\s+(?:-|–)\s+Palm Jumeirah/i, confidence: 'high'},
    {regex: /(Frond\s+[A-Z]\s+Villa)/i, confidence: 'high'},
    
    # Medium confidence
    {regex: /(?:at|@)\s+([A-Z][A-Za-z\s&]+(?:Residences?|Tower|Building|Apartments?))/i, confidence: 'medium'},
    {regex: /^([A-Z][A-Za-z\s&]+(?:Residences?|Tower|Building))/i, confidence: 'medium'},
    
    # Lower confidence (title only)
    {regex: /(The\s+[A-Z][A-Za-z\s]+(?:Residences?|Tower))/i, confidence: 'medium'},
  ]
  
  patterns.each do |p|
    match = text.match(p[:regex])
    return [match[1].strip, p[:confidence]] if match
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
  
  # Skip rows without Airbnb URL
  unless airbnb_url && airbnb_url.start_with?('http')
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, nil, nil, nil, row['Revenue Potential'], 
              row['Days Available'], row['Annual Revenue'], row['Occupancy'], 
              row['Daily Rate'], row['Bedrooms']]
    end
    next
  end
  
  begin
    puts "\n[#{count}/#{processed}] #{airbnb_id}"
    
    driver.get(airbnb_url)
    sleep(4)
    
    doc = Nokogiri::HTML(driver.page_source)
    
    # Extract all text
    title = doc.css('h1').first&.text&.strip || ""
    description = doc.css('[data-section-id="DESCRIPTION_DEFAULT"]').text
    location = doc.css('div[data-section-id="LOCATION_DEFAULT"]').text
    
    full_text = "#{title}\n#{description}\n#{location}"
    
    puts "  Title: #{title[0..60]}"
    
    # Try text extraction first
    building, confidence = extract_building_from_text(full_text)
    method = 'text'
    
    if building
      puts "  ✓ Building: #{building} (#{confidence})"
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
      method = 'needs_ocr'
      confidence = 'pending'
    end
    
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, building, confidence, method,
              row['Revenue Potential'], row['Days Available'], 
              row['Annual Revenue'], row['Occupancy'], row['Daily Rate'], row['Bedrooms']]
    end
    
    processed += 1
    sleep(2)
    
  rescue => e
    puts "  ERROR: #{e.message}"
    CSV.open(OUTPUT_CSV, 'a') do |csv|
      csv << [airbnb_id, airbnb_url, nil, nil, 'error',
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