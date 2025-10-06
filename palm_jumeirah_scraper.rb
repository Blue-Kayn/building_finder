#!/usr/bin/env ruby
require 'selenium-webdriver'
require 'csv'
require 'set'

options = Selenium::WebDriver::Chrome::Options.new
profile_dir = File.join(Dir.pwd, 'chrome_scraper_profile')
options.add_argument("--user-data-dir=#{profile_dir}")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
driver = Selenium::WebDriver.for :chrome, options: options

driver.get("https://app.airdna.co/")
puts "Login, press ENTER..."
gets

driver.get("https://app.airdna.co/data/ae/30858/140856/top-listings?lat=25.117795&lng=55.134474&zoom=12&tab=active-str-listings")
sleep(10)

CSV.open("palm_jumeirah_data.csv", "w") do |csv|
  csv << ['Airbnb ID', 'Airbnb URL', 'Revenue Potential', 'Days Available', 'Annual Revenue', 'Occupancy', 'Daily Rate', 'Bedrooms']
end

processed = Set.new
count = 0

# Find scrollable container
container = driver.find_elements(css: 'div[style*="overflow"]').find { |el| 
  el.find_elements(css: 'div[data-testid="listing-card"]').length > 5 
}

puts container ? "Found scrollable container" : "Scrolling window"

100.times do |scroll|
  cards = driver.find_elements(css: 'div[data-testid="listing-card"]')
  puts "[#{scroll}] #{cards.length} cards"
  
  new_count = 0
  
  cards.each do |card|
    text = card.text
    
    # Try to find Airbnb link, but proceed even if none
    link = card.find_elements(css: 'a[href*="airbnb.com/rooms/"]').first
    
    if link
      url = link.attribute('href')
      id = url[/rooms\/(\d+)/, 1]
    else
      # No Airbnb link - use card text as unique ID
      id = text.hash.abs.to_s
      url = nil
    end
    
    next if processed.include?(id)
    
    data = [
      id,
      url,
      text[/(\S+)\s*Revenue Potential/i, 1],
      text[/(\d+)\s*Days Available/i, 1],
      text[/(\S+)\s*Revenue\s*$/im, 1],
      text[/(\d+)%\s*Occupancy/i, 1],
      text[/(\S+)\s*Daily Rate/i, 1],
      text[/(\d+)\s*bed/i, 1]
    ]
    
    CSV.open("palm_jumeirah_data.csv", "a") { |csv| csv << data }
    processed.add(id)
    count += 1
    new_count += 1
    puts "  [#{count}] #{id}#{url ? '' : ' (no airbnb)'}"
  end
  
  break if new_count == 0 && scroll > 15
  
  # Scroll to last card to trigger lazy loading
  last_card = cards.last
  if last_card
    driver.execute_script("arguments[0].scrollIntoView({block: 'end'})", last_card)
  elsif container
    driver.execute_script("arguments[0].scrollBy(0, 800)", container)
  else
    driver.execute_script("window.scrollBy(0, 800)")
  end
  
  # Wait longer for cards to load
  sleep(5)
end

puts "\nDone: #{count} properties"
driver.quit