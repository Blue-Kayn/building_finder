# coordinate_validator.rb
# Validates building matches using location detection and distance

require_relative 'building_database'

module CoordinateValidator
  DISTANCE_THRESHOLD = 400 # meters
  DUBAI_LAT_RANGE = (24.5..25.5)
  DUBAI_LNG_RANGE = (54.5..56.0)

  # Extract coordinates from Airbnb page source
  def self.extract_from_page(driver)
    page_source = driver.page_source

    patterns = [
      /"latitude":([\d.-]+),"longitude":([\d.-]+)/,
      /"latitude":\s*([\d.-]+)\s*,\s*"longitude":\s*([\d.-]+)/,
      /'latitude':([\d.-]+),'longitude':([\d.-]+)/,
      /latitude&quot;:([\d.-]+),&quot;longitude&quot;:([\d.-]+)/
    ]

    patterns.each do |pattern|
      if page_source =~ pattern
        lat, lng = $1.to_f, $2.to_f

        if valid_dubai_coordinates?(lat, lng)
          puts "    ✓ Extracted coords: #{lat}, #{lng}"
          return [lat, lng]
        else
          puts "    ⚠ Found coords (#{lat}, #{lng}) but outside Dubai range"
        end
      end
    end

    puts "    ⚠ Could not find coordinates"
    [nil, nil]

  rescue => e
    puts "    Failed to extract coordinates: #{e.message}"
    [nil, nil]
  end

  # Validate building match using location detection and distance
  def self.validate(listing_lat, listing_lng, building_name)
    return { status: 'no_coords', distance: nil, location: nil } if listing_lat.nil? || listing_lng.nil?

    # CRITICAL: Detect location from coordinates FIRST
    location = BuildingDatabase.detect_location(listing_lat, listing_lng)
    
    unless location
      puts "  ⚠️ Listing coordinates outside known areas"
      return { status: 'unknown_location', distance: nil, location: nil }
    end

    location_display = BuildingDatabase.location_display_name(location)
    puts "  📍 Detected location: #{location_display}"

    # Extract canonical building name from formatted name
    canonical = extract_canonical_name(building_name)

    # Get coordinates for this building in THIS location only
    building_coords = BuildingDatabase.coordinates(canonical, location)
    
    unless building_coords
      puts "  ⚠️ Building '#{canonical}' not found in #{location_display}"
      return { status: 'wrong_location', distance: nil, location: location }
    end

    distance = calculate_distance(listing_lat, listing_lng, building_coords[0], building_coords[1])
    
    puts "  📏 Distance from #{canonical}: #{distance.round}m"

    if distance <= DISTANCE_THRESHOLD
      { status: 'validated', distance: distance.round, location: location }
    else
      { status: 'manual_check', distance: distance.round, location: location }
    end
  end

  # Find closest building when no text match (fallback mode)
  def self.find_closest_building(listing_lat, listing_lng)
    return { building: nil, distance: nil, location: nil } if listing_lat.nil? || listing_lng.nil?

    location = BuildingDatabase.detect_location(listing_lat, listing_lng)
    return { building: nil, distance: nil, location: nil } unless location

    buildings = BuildingDatabase.buildings_for_location(location)
    closest = nil
    min_distance = Float::INFINITY

    buildings.each do |building_name, building_data|
      coords = building_data[:coords]
      distance = calculate_distance(listing_lat, listing_lng, coords[0], coords[1])
      
      if distance < min_distance
        min_distance = distance
        closest = building_name
      end
    end

    if closest && min_distance <= DISTANCE_THRESHOLD
      formatted = BuildingDatabase.format_full_name(closest, location)
      puts "  🎯 Closest building by coordinates: #{closest} (#{min_distance.round}m)"
      { building: formatted, distance: min_distance.round, location: location }
    else
      { building: nil, distance: nil, location: location }
    end
  end

  private

  # Extract canonical building name from formatted name (removes complex/location suffix)
  def self.extract_canonical_name(formatted_name)
    return formatted_name unless formatted_name
    
    # Format is: "BUILDING NAME, COMPLEX, LOCATION" or "BUILDING NAME, LOCATION"
    parts = formatted_name.split(',').map(&:strip)
    parts.first # Return just the building name
  end

  # Haversine formula for distance calculation
  def self.calculate_distance(lat1, lon1, lat2, lon2)
    return nil if [lat1, lon1, lat2, lon2].any?(&:nil?)

    rad_per_deg = Math::PI / 180
    earth_radius = 6371000 # meters

    dlat = (lat2 - lat1) * rad_per_deg
    dlon = (lon2 - lon1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 + 
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) * 
        Math.sin(dlon / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    earth_radius * c
  end

  # Validate coordinates are within Dubai range
  def self.valid_dubai_coordinates?(lat, lng)
    DUBAI_LAT_RANGE.cover?(lat) && DUBAI_LNG_RANGE.cover?(lng)
  end
end