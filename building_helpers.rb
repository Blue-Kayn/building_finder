# building_helpers.rb
# Main interface for building extraction and validation
# Provides backward-compatible functions for extract_buildings.rb

require 'selenium-webdriver'
require 'nokogiri'
require 'csv'
require 'fileutils'

require_relative 'building_database'
require_relative 'text_extractor'
require_relative 'coordinate_validator'

# Check if property is a villa based on type and title
def is_villa?(doc, title)
  # Check property type subtitle
  property_type_element = doc.css('h2').find { |h2| h2.text.match?(/Entire .+ in Dubai/i) }
  
  property_type_from_subtitle = false
  if property_type_element
    property_type_text = property_type_element.text
    puts "    Property type: #{property_type_text}"
    
    property_type_from_subtitle = property_type_text.match?(/Entire\s+(villa|townhouse|vacation\s+home|home|house)\s+in/i)
  end

  # Check title for villa indicators
  villa_in_title = title.match?(/\b(villa|townhouse|beach\s+house)\b/i)

  # Villa if EITHER check passes
  if property_type_from_subtitle || villa_in_title
    if property_type_from_subtitle && villa_in_title
      puts "    ✓ Villa confirmed by BOTH subtitle and title"
    elsif villa_in_title
      puts "    ✓ Villa detected in title"
    else
      puts "    ✓ Villa detected in subtitle"
    end
    return true
  end

  false
end

# Extract coordinates from Airbnb page
def extract_coordinates(driver)
  CoordinateValidator.extract_from_page(driver)
end

# Calculate distance between two points
def calculate_distance(lat1, lon1, lat2, lon2)
  CoordinateValidator.send(:calculate_distance, lat1, lon1, lat2, lon2)
end

# Get building coordinates (backward compatibility - deprecated, uses location detection)
def get_building_coordinates(building_name)
  # This function is kept for backward compatibility but is deprecated
  # It tries to find coordinates across all locations (not recommended)
  BuildingDatabase::LOCATIONS.each do |location, location_data|
    coords = BuildingDatabase.coordinates(building_name, location)
    return coords if coords
  end
  nil
end

# Extract building name from text (NEW: location-aware)
# Returns: [building_name_with_location, confidence]
def extract_building_from_text(text, listing_lat = nil, listing_lng = nil)
  # Detect location from coordinates if provided
  location = nil
  if listing_lat && listing_lng
    location = BuildingDatabase.detect_location(listing_lat, listing_lng)
  end

  # If no location detected, try Palm Jumeirah as default (backward compatibility)
  location ||= 'PALM_JUMEIRAH'

  result = TextExtractor.extract(text, location)
  
  # If no text match, try finding closest building by coordinates
  if result[0].nil? && listing_lat && listing_lng
    closest = CoordinateValidator.find_closest_building(listing_lat, listing_lng)
    if closest[:building]
      puts "    💡 No text match - using closest building by coordinates"
      return [closest[:building], 'coord_only']
    end
  end
  
  result
end

# Validate building extraction with coordinates (NEW: location-aware)
# Returns: { status:, distance:, location: }
def validate_building_extraction(listing_lat, listing_lng, building_name)
  CoordinateValidator.validate(listing_lat, listing_lng, building_name)
end