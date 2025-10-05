#!/usr/bin/env ruby
# palm_jumeirah_scraper.rb
# 
# Scrapes AirDNA property data for Palm Jumeirah and extracts building names from Airbnb
# 
# Usage: ruby palm_jumeirah_scraper.rb

require 'selenium-webdriver'
require 'nokogiri'
require 'csv'
require 'json'
require 'uri'

class PalmJumeirahScraper
  AIRDNA_LOGIN_URL = "https://app.airdna.co/login"
  # Updated to use top-listings view where we can see all properties as cards
  AIRDNA_MAP_URL = "https://app.airdna.co/data/ae/30858/140856/top-listings?lat=25.117795&lng=55.13165&zoom=13"
  OUTPUT_FILE = "palm_jumeirah_data.csv"
  
  def initialize
    setup_driver
    @properties = []
    setup_csv_file
  end
  
  def setup_csv_file
    # Create CSV with headers if it doesn't exist
    unless File.exist?(OUTPUT_FILE)
      CSV.open(OUTPUT_FILE, 'w') do |csv|
        csv << [
          'Airbnb ID',
          'Building Name',
          'Address',
          'Bedrooms',
          'Revenue Potential',
          'Annual Revenue',
          'Days Available',
          'Occupancy (%)',
          'ADR',
          'Title',
          'Airbnb URL'
        ]
      end
      puts "Created CSV file: #{OUTPUT_FILE}"
    end
  end
  
  def save_property_to_csv(property_data)
    # Append property to CSV immediately after scraping
    CSV.open(OUTPUT_FILE, 'a') do |csv|
      csv << [
        property_data[:airbnb_id],
        property_data[:building_name],
        property_data[:address],
        property_data[:bedrooms],
        property_data[:revenue_potential],
        property_data[:annual_revenue],
        property_data[:days_available],
        property_data[:occupancy],
        property_data[:adr],
        property_data[:full_title],
        property_data[:airbnb_url]
      ]
    end
    puts "  Saved to CSV"
  end
  
  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    
    # Use a separate profile directory for the scraper (avoids conflicts)
    scraper_profile = File.join(Dir.pwd, 'chrome_scraper_profile')
    
    puts "Using dedicated scraper profile: #{scraper_profile}"
    
    options.add_argument("--user-data-dir=#{scraper_profile}")
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--no-first-run')
    options.add_argument('--no-default-browser-check')
    
    puts "Initializing browser..."
    @driver = Selenium::WebDriver.for :chrome, options: options
    @wait = Selenium::WebDriver::Wait.new(timeout: 20)
    
    puts "Browser initialized"
  end
  
  def manual_login
    puts "\n" + "="*60
    puts "MANUAL LOGIN REQUIRED"
    puts "="*60
    
    puts "\nOpening AirDNA login page..."
    @driver.get("https://app.airdna.co/")
    
    puts "\nInstructions:"
    puts "1. The browser window has opened to AirDNA"
    puts "2. Please log in with your credentials"
    puts "3. Complete any 2FA or CAPTCHA if required"
    puts "4. Wait until you see the AirDNA dashboard"
    puts "5. Press ENTER in this terminal to continue..."
    puts "\nWaiting for you to log in..."
    
    gets # Wait for user to press Enter
    
    puts "Login complete, continuing with scrape..."
    sleep(2)
  end
  
  def navigate_to_palm_jumeirah
    puts "\nNavigating to Palm Jumeirah listings..."
    @driver.get(AIRDNA_MAP_URL)
    sleep(5) # Wait for page to load
    
    puts "Page loaded - waiting for listings to appear..."
    sleep(3)
  end
  
  def scroll_to_load_all_listings
    puts "\nScrolling to load all listings..."
    
    # Find the listings container (left side)
    listings_container = @driver.find_element(css: 'div[class*="listing"], div[class*="card"]') rescue nil
    
    if listings_container
      # Scroll down multiple times to load lazy-loaded listings
      5.times do |i|
        @driver.execute_script("window.scrollBy(0, 500);")
        sleep(1)
        puts "  Scroll #{i+1}/5..."
      end
    end
    
    sleep(2)
  end
  
  def get_all_listing_cards
    puts "\nFinding all property listing cards..."
    
    # These selectors target the property cards on the left side
    # We'll need to adjust based on actual HTML structure
    cards = []
    
    # Try different possible selectors for listing cards
    selectors = [
      'div[class*="PropertyCard"]',
      'div[class*="ListingCard"]',
      'a[href*="/property/"]',
      'div[data-testid*="listing"]',
      '[class*="property-card"]'
    ]
    
    selectors.each do |selector|
      begin
        found = @driver.find_elements(css: selector)
        if found.length > 0
          puts "Found #{found.length} cards with selector: #{selector}"
          cards = found
          break
        end
      rescue
        next
      end
    end
    
    # If no specific selector works, look for all clickable elements with property data
    if cards.empty?
      puts "Trying generic approach - looking for elements with revenue/occupancy text..."
      cards = @driver.find_elements(xpath: '//*[contains(text(), "Revenue") or contains(text(), "Occupancy")]/..')
    end
    
    puts "Found #{cards.length} property listings"
    cards
  end
  
  def scrape_listing_card(card, index, total)
    begin
      puts "\n[#{index}/#{total}] Processing listing..."
      
      property_data = {}
      
      # Get all text from the card
      card_text = card.text
      
      # Extract data from card text using patterns
      property_data[:revenue_potential] = extract_value(card_text, /(\d+\.?\d*[mk]?)\s*Revenue Potential/i)
      property_data[:days_available] = extract_value(card_text, /(\d+)\s*Days Available/i)
      property_data[:annual_revenue] = extract_value(card_text, /(\d+\.?\d*[mk]?)\s*Revenue(?!\sPotential)/i)
      property_data[:occupancy] = extract_value(card_text, /(\d+)%\s*Occupancy/i)
      property_data[:adr] = extract_value(card_text, /(\d+\.?\d*[mk]?)\s*Daily Rate/i)
      
      # Extract bedrooms, bathrooms
      property_data[:bedrooms] = extract_value(card_text, /(\d+)\s*(?:bed|BR)/i)
      
      # Try to find Airbnb link by clicking the card
      begin
        # Scroll card into view and wait
        @driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", card)
        sleep(2)
        
        # Use JavaScript to click to avoid interception issues
        @driver.execute_script("arguments[0].click();", card)
        sleep(3)
        
        # Look for Airbnb icon/link in the detail view
        airbnb_link = find_airbnb_link
        
        if airbnb_link
          airbnb_url = airbnb_link.attribute('href')
          property_data[:airbnb_url] = airbnb_url
          property_data[:airbnb_id] = extract_airbnb_id(airbnb_url)
          
          # Open Airbnb in new tab to scrape building name
          building_info = scrape_airbnb_listing(airbnb_url)
          property_data.merge!(building_info)
          
          puts "  #{property_data[:building_name] || 'Building name not found'}"
        else
          puts "  Airbnb link not found"
        end
        
        # Close detail view
        close_detail_panel
        
      rescue => e
        puts "  Warning: Could not process detail view: #{e.message}"
        # Try to close any open modals before continuing
        close_detail_panel
      end
      
      # Save to CSV immediately after scraping
      unless property_data.empty?
        @properties << property_data
        save_property_to_csv(property_data)
      end
      
    rescue => e
      puts "  Error processing listing: #{e.message}"
    end
  end
  
  def extract_value(text, pattern)
    match = text.match(pattern)
    match ? match[1] : nil
  end
  
  def find_airbnb_link
    # The Airbnb icon is overlaid on the top-left of the property images
    # Look for it in the image gallery area
    selectors = [
      'a[href*="airbnb.com"]',
      'img[alt*="Airbnb"]',
      'img[alt*="airbnb"]',
      'svg[aria-label*="Airbnb"]',
      '[data-testid*="airbnb"]',
      # Check in the photo gallery overlay area
      'div[class*="gallery"] a[href*="airbnb"]',
      'div[class*="image"] a[href*="airbnb"]',
      # Sometimes it's an img inside a link
      'a img[src*="airbnb"]'
    ]
    
    selectors.each do |selector|
      begin
        elements = @driver.find_elements(css: selector)
        elements.each do |element|
          # Try to find the parent link
          if element.tag_name == 'a'
            return element
          else
            parent_link = element.find_element(xpath: './ancestor::a') rescue nil
            return parent_link if parent_link
          end
        end
      rescue
        next
      end
    end
    
    # If still not found, try clicking the main image area to see if icons appear
    begin
      main_image = @driver.find_element(css: 'img[class*="property"], img[class*="listing"]')
      main_image.click
      sleep(1)
      
      # Try again after clicking
      airbnb_link = @driver.find_element(css: 'a[href*="airbnb.com"]') rescue nil
      return airbnb_link if airbnb_link
    rescue
    end
    
    nil
  end
  
  def extract_airbnb_id(url)
    match = url.match(/rooms\/(\d+)/)
    match ? match[1] : nil
  end
  
  def scrape_airbnb_listing(url)
    data = { building_name: nil, address: nil }
    
    begin
      # Open in new tab
      @driver.execute_script("window.open('#{url}', '_blank');")
      @driver.switch_to.window(@driver.window_handles.last)
      
      sleep(3)
      
      # Get page HTML
      html = @driver.page_source
      doc = Nokogiri::HTML(html)
      
      # Extract building name from title and description
      title = doc.css('h1').first&.text || ""
      description = doc.css('[data-section-id="DESCRIPTION_DEFAULT"]').text || ""
      
      full_text = "#{title} #{description}"
      
      data[:building_name] = extract_building_name(full_text)
      data[:full_title] = title
      
      # Try to get address
      location = doc.css('[data-section-id="LOCATION_DEFAULT"]').first&.text
      data[:address] = location if location
      
      # Close the Airbnb tab
      @driver.close
      @driver.switch_to.window(@driver.window_handles.first)
      
    rescue => e
      puts "  Warning: Error scraping Airbnb: #{e.message}"
      begin
        @driver.close if @driver.window_handles.length > 1
        @driver.switch_to.window(@driver.window_handles.first)
      rescue
      end
    end
    
    data
  end
  
  def extract_building_name(text)
    patterns = [
      /(?:in|at|@)\s+([A-Z][A-Za-z\s]+(?:Residences?|Tower|Building|Apartments?|Villas?))/i,
      /^([A-Z][A-Za-z\s]+(?:Residences?|Tower|Building|Apartments?|Villas?))/i,
      /\|\s*([A-Z][A-Za-z\s]+(?:Residences?|Tower|Building|Apartments?))\s*\|/i,
      /(Frond\s+[A-Z]\s+Villa)/i,
      /([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+(?:Residences?|Tower|Building|Apartments?|Heights|Court))/
    ]
    
    patterns.each do |pattern|
      match = text.match(pattern)
      return match[1].strip if match
    end
    
    words = text.scan(/\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b/)
    potential_names = words.select { |w| w.split.length >= 2 && w.length > 10 }
    
    potential_names.first
  end
  
  def close_detail_panel
    # Try clicking outside the modal multiple times to ensure it closes
    3.times do
      begin
        # Click on the map area (right side of screen)
        @driver.action.move_to_location(1400, 400).click.perform
        sleep(1)
      rescue
      end
    end
    
    # Also try ESC key
    @driver.action.send_keys(:escape).perform
    sleep(2)
    
    # Verify the modal is actually closed by checking if listing cards are clickable again
    begin
      test_card = @driver.find_element(css: 'div[data-testid="listing-card"]')
      test_card.displayed?
      puts "    Modal closed successfully"
    rescue
      puts "    Warning: Modal might still be open"
    end
  end
  
  def export_to_csv
    # Data is already saved incrementally, just show summary
    puts "\nAll data has been saved incrementally to #{OUTPUT_FILE}"
    puts "Total properties scraped: #{@properties.length}"
  end
  
  def run
    puts "\n" + "="*60
    puts "PALM JUMEIRAH AIRDNA SCRAPER"
    puts "="*60
    
    begin
      # Step 1: Manual login
      manual_login
      
      # Step 2: Navigate to Palm Jumeirah
      navigate_to_palm_jumeirah
      
      # Step 3: Scroll to load all listings
      scroll_to_load_all_listings
      
      # Step 4: Get all listing cards
      cards = get_all_listing_cards
      
      # Step 5: Scrape each listing
      puts "\nStarting property scrape..."
      cards.each_with_index do |card, index|
        scrape_listing_card(card, index + 1, cards.length)
        sleep(1 + rand(2))
      end
      
      # Step 6: Export to CSV
      export_to_csv
      
      puts "\n" + "="*60
      puts "SCRAPING COMPLETE"
      puts "="*60
      puts "Total properties scraped: #{@properties.length}"
      puts "Output file: #{OUTPUT_FILE}"
      
    rescue => e
      puts "\nFatal error: #{e.message}"
      puts e.backtrace.first(5)
    ensure
      @driver.quit if @driver
      puts "\nBrowser closed"
    end
  end
end

# Run the scraper
if __FILE__ == $0
  scraper = PalmJumeirahScraper.new
  scraper.run
end