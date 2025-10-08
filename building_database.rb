# building_database.rb
# ENTERPRISE-GRADE building database with validation, metadata, and scalability
# Designed to handle 10,000+ buildings across all Dubai areas

module BuildingDatabase
  # Database version for tracking updates
  DATABASE_VERSION = '2.0.0'
  LAST_UPDATED = '2025-01-08'

  # Location definitions with precise boundaries
  LOCATIONS = {
    'PALM_JUMEIRAH' => {
      display_name: 'Palm Jumeirah',
      bounds: {
        lat: (25.09..25.14),
        lng: (55.10..55.16)
      },
      description: 'Iconic palm-shaped artificial archipelago',
      buildings: load_palm_jumeirah_buildings
    }
    # Future locations added here - JVC, Downtown Dubai, Marina, etc.
  }.freeze

  # Load Palm Jumeirah buildings (separated for maintainability)
  def self.load_palm_jumeirah_buildings
    {
      'ATLANTIS THE PALM' => {
        coords: [25.130388378334434, 55.11713265962359],
        aliases: ['ATLANTIS THE PALM', 'ATLANTIS'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2008,
          floors: 23,
          units: 1539,
          developer: 'Kerzner International'
        }
      },
      'ROYAL ATLANTIS' => {
        coords: [25.138565117680006, 55.12776223842851],
        aliases: ['ROYAL ATLANTIS', 'THE ROYAL ATLANTIS'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2023,
          floors: 43,
          units: 795,
          developer: 'Kerzner International'
        }
      },
      'FIVE PALM JUMEIRAH' => {
        coords: [25.104334288891593, 55.14869174441605],
        aliases: ['FIVE PALM JUMEIRAH', 'FIVE AT PALM JUMEIRAH', 'FIVE PALM', 'FIVE'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2016,
          floors: 16,
          units: 221,
          developer: 'Five Holdings'
        }
      },
      'ONE AT PALM JUMEIRAH' => {
        coords: [25.103402706459573, 55.14986241168743],
        aliases: ['ONE AT PALM JUMEIRAH', 'ONE PALM', 'ONE'],
        metadata: {
          type: 'residential',
          year_built: 2023,
          floors: 94,
          units: 430,
          developer: 'Dorchester Collection'
        }
      },
      'BALQIS RESIDENCES' => {
        coords: [25.120052744264747, 55.11042703301607],
        aliases: ['BALQIS RESIDENCES', 'BALQIS RESIDENCE', 'BALQIS', 'WYNDHAM'],
        metadata: {
          type: 'residential',
          year_built: 2014,
          floors: 30,
          units: 330,
          developer: 'Nakheel'
        }
      },
      'THE 8' => {
        coords: [25.117548557810736, 55.10962743471458],
        aliases: ['THE 8', 'THE EIGHT'],
        metadata: {
          type: 'residential',
          year_built: 2015,
          floors: 21,
          units: 155,
          developer: 'Nakheel'
        }
      },
      'THE PALM TOWER' => {
        coords: [25.113777438518582, 55.13997665598321],
        aliases: ['THE PALM TOWER', 'PALM TOWER', 'ST REGIS RESIDENCES'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2021,
          floors: 52,
          units: 432,
          developer: 'Nakheel'
        }
      },
      'OCEANA RESIDENCES' => {
        coords: [25.11107232148635, 55.13739886438929],
        aliases: ['OCEANA RESIDENCES', 'OCEANA HOTEL', 'OCEANA APARTMENTS', 'OCEANA'],
        sub_buildings: ['ADRIATIC', 'PACIFIC', 'CARIBBEAN', 'ATLANTIC', 'AEGEAN', 'BALTIC', 'SOUTHERN'],
        metadata: {
          type: 'residential',
          year_built: 2010,
          floors: 14,
          units: 469,
          developer: 'Seven Tides'
        }
      },
      'GOLDEN MILE 1' => {
        coords: [25.105619489933705, 55.14913118598946],
        aliases: ['GOLDEN MILE 1'],
        complex: 'GOLDEN MILE',
        metadata: {
          type: 'residential',
          year_built: 2010,
          floors: 9,
          developer: 'Nakheel'
        }
      },
      'GOLDEN MILE 2' => {
        coords: [25.106212236464216, 55.148339016322254],
        aliases: ['GOLDEN MILE 2'],
        complex: 'GOLDEN MILE',
        metadata: {
          type: 'residential',
          year_built: 2010,
          floors: 9,
          developer: 'Nakheel'
        }
      },
      'GOLDEN MILE 3' => {
        coords: [25.10671670090406, 55.14760824734748],
        aliases: ['GOLDEN MILE 3'],
        complex: 'GOLDEN MILE',
        metadata: {
          type: 'residential',
          year_built: 2010,
          floors: 9,
          developer: 'Nakheel'
        }
      },
      'GOLDEN MILE 4' => {
        coords: [25.10727426445531, 55.14686620100142],
        aliases: ['GOLDEN MILE 4'],
        complex: 'GOLDEN MILE',
        metadata: {
          type: 'residential',
          year_built: 2010,
          floors: 9,
          developer: 'Nakheel'
        }
      },
      'GOLDEN MILE 5' => {
        coords: [25.107855758900406, 55.14621994090272],
        aliases: ['GOLDEN MILE 5'],
        complex: 'GOLDEN MILE',
        metadata: {
          type: 'residential',
          year_built: 2010,
          floors: 9,
          developer: 'Nakheel'
        }
      },
      'GOLDEN MILE 6' => {
        coords: [25.10839502095261, 55.145414830750354],
        aliases: ['GOLDEN MILE 6'],
        complex: 'GOLDEN MILE',
        metadata: {
          type: 'residential',
          year_built: 2010,
          floors: 9,
          developer: 'Nakheel'
        }
      },
      'FAIRMONT PALM' => {
        coords: [25.110073307281326, 55.14096748283601],
        aliases: ['FAIRMONT PALM', 'FAIRMONT', 'FAIRMONT THE PALM'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2012,
          floors: 19,
          units: 381,
          developer: 'IFA Hotels & Resorts'
        }
      },
      'RAFFLES THE PALM' => {
        coords: [25.110391805920685, 55.10984132296129],
        aliases: ['RAFFLES THE PALM', 'RAFFLES PALM', 'RAFFLES'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2013,
          floors: 23,
          units: 389,
          developer: 'Al Hamra Real Estate'
        }
      },
      'W PALM' => {
        coords: [25.106393320449566, 55.11109321054681],
        aliases: ['W PALM', 'W DUBAI', 'W RESIDENCES', 'W THE PALM'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2018,
          floors: 52,
          units: 350,
          developer: 'Aldar Properties'
        }
      },
      'DUKES PALM' => {
        coords: [25.112505003046053, 55.13798895001271],
        aliases: ['DUKES PALM', 'DUKES THE PALM', 'DUKES HOTEL'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2019,
          floors: 15,
          units: 279,
          developer: 'Seven Tides'
        }
      },
      'RIXOS PALM' => {
        coords: [25.121391364265154, 55.15366257545908],
        aliases: ['RIXOS PALM', 'RIXOS THE PALM', 'RIXOS'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2013,
          floors: 17,
          units: 231,
          developer: 'Nakheel'
        }
      },
      'EMAAR BEACHFRONT' => {
        coords: [25.098499137118534, 55.14055790317492],
        aliases: ['EMAAR BEACHFRONT', 'MARINA VISTA', 'BEACH ISLE', 'BEACH VISTA', 
                  'SUNRISE BAY', 'GRAND BLEU', 'PALACE BEACH RESIDENCE', 'PALACE BEACH'],
        sub_buildings: ['MARINA VISTA TOWER 1', 'MARINA VISTA TOWER 2', 'MARINA VISTA TOWER 3',
                       'BEACH ISLE', 'BEACH VISTA', 'SUNRISE BAY TOWER 1', 'SUNRISE BAY TOWER 2',
                       'GRAND BLEU TOWER', 'PALACE BEACH RESIDENCE'],
        metadata: {
          type: 'residential_community',
          year_built: 2018,
          developer: 'Emaar Properties'
        }
      },
      'SEVEN PALM' => {
        coords: [25.111664183271177, 55.1384718941355],
        aliases: ['SEVEN PALM', 'SEVEN HOTEL', 'SEVEN HOTEL AND APARTMENTS'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2015,
          floors: 16,
          units: 365,
          developer: 'Seven Tides'
        }
      },
      'DREAM PALM' => {
        coords: [25.122250891414193, 55.15441076121446],
        aliases: ['DREAM PALM', 'DREAM'],
        metadata: {
          type: 'residential',
          year_built: 2016,
          floors: 17,
          units: 162,
          developer: 'Seven Tides'
        }
      },
      'ANANTARA' => {
        coords: [25.128449833201703, 55.153966635909235],
        aliases: ['ANANTARA', 'ANANTARA PALM', 'ANANTARA THE PALM', 'ANANTARA RESIDENCES'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2014,
          floors: 13,
          units: 293,
          developer: 'Anantara Hotels'
        }
      },
      'AZIZI MINA' => {
        coords: [25.12693592140891, 55.15349219365068],
        aliases: ['AZIZI MINA', 'MINA', 'MINA BY AZIZI'],
        metadata: {
          type: 'residential',
          year_built: 2024,
          floors: 33,
          units: 444,
          developer: 'Azizi Developments'
        }
      },
      'AZURE RESIDENCES' => {
        coords: [25.10704187688564, 55.15260914087014],
        aliases: ['AZURE RESIDENCES', 'AZURE', 'AZURE THE PALM'],
        metadata: {
          type: 'residential',
          year_built: 2018,
          floors: 12,
          units: 180,
          developer: 'Nakheel'
        }
      },
      'TIARA RESIDENCES' => {
        coords: [25.11545265573328, 55.14038718458433],
        aliases: ['TIARA RESIDENCES', 'TIARA', 'TIARA PALM'],
        metadata: {
          type: 'residential',
          year_built: 2014,
          floors: 30,
          units: 394,
          developer: 'Nakheel'
        }
      },
      'CLUB VISTA MARE' => {
        coords: [25.1151808834005, 55.14235758142192],
        aliases: ['CLUB VISTA MARE', 'VISTA MARE'],
        metadata: {
          type: 'residential',
          year_built: 2015,
          floors: 12,
          units: 96,
          developer: 'Nakheel'
        }
      },
      'MARINA RESIDENCES 1' => {
        coords: [25.112941125796883, 55.1366317393548],
        aliases: ['MARINA RESIDENCES 1'],
        complex: 'MARINA RESIDENCES',
        metadata: {
          type: 'residential',
          year_built: 2008,
          floors: 48,
          developer: 'Nakheel'
        }
      },
      'MARINA RESIDENCES 2' => {
        coords: [25.113800152895834, 55.136152256723555],
        aliases: ['MARINA RESIDENCES 2'],
        complex: 'MARINA RESIDENCES',
        metadata: {
          type: 'residential',
          year_built: 2008,
          floors: 48,
          developer: 'Nakheel'
        }
      },
      'MARINA RESIDENCES 3' => {
        coords: [25.11479453116967, 55.13620384995259],
        aliases: ['MARINA RESIDENCES 3'],
        complex: 'MARINA RESIDENCES',
        metadata: {
          type: 'residential',
          year_built: 2008,
          floors: 48,
          developer: 'Nakheel'
        }
      },
      'MARINA RESIDENCES 4' => {
        coords: [25.116189316626393, 55.13759686719626],
        aliases: ['MARINA RESIDENCES 4'],
        complex: 'MARINA RESIDENCES',
        metadata: {
          type: 'residential',
          year_built: 2008,
          floors: 48,
          developer: 'Nakheel'
        }
      },
      'MARINA RESIDENCES 5' => {
        coords: [25.116382850191844, 55.13857345340445],
        aliases: ['MARINA RESIDENCES 5'],
        complex: 'MARINA RESIDENCES',
        metadata: {
          type: 'residential',
          year_built: 2008,
          floors: 48,
          developer: 'Nakheel'
        }
      },
      'MARINA RESIDENCES 6' => {
        coords: [25.116032487484, 55.13961637367663],
        aliases: ['MARINA RESIDENCES 6'],
        complex: 'MARINA RESIDENCES',
        metadata: {
          type: 'residential',
          year_built: 2008,
          floors: 48,
          developer: 'Nakheel'
        }
      },
      'RUBY' => {
        coords: [25.116585047795336, 55.141380433947011],
        aliases: ['RUBY', 'RUBY RESIDENCES'],
        metadata: {
          type: 'residential',
          year_built: 2015,
          floors: 10,
          developer: 'Nakheel'
        }
      },
      'DIAMOND' => {
        coords: [25.1174082037247, 55.142025961052084],
        aliases: ['DIAMOND', 'DIAMOND RESIDENCES'],
        metadata: {
          type: 'residential',
          year_built: 2015,
          floors: 10,
          developer: 'Nakheel'
        }
      },
      'TANZANITE' => {
        coords: [25.115815549047024, 55.14254052800524],
        aliases: ['TANZANITE', 'TANZANITE RESIDENCES'],
        metadata: {
          type: 'residential',
          year_built: 2015,
          floors: 10,
          developer: 'Nakheel'
        }
      },
      'EMERALD' => {
        coords: [25.116157421463427, 55.14105449639319],
        aliases: ['EMERALD', 'EMERALD RESIDENCES'],
        metadata: {
          type: 'residential',
          year_built: 2015,
          floors: 10,
          developer: 'Nakheel'
        }
      },
      'ROYAL AMWAJ' => {
        coords: [25.128449833201703, 55.153966635909235],
        aliases: ['ROYAL AMWAJ', 'ROYAL AMWAJ RESIDENCES'],
        metadata: {
          type: 'residential',
          year_built: 2009,
          floors: 14,
          units: 104,
          developer: 'Nakheel'
        }
      },
      'ROYAL BAY' => {
        coords: [25.125271418545978, 55.15323450905715],
        aliases: ['ROYAL BAY', 'ROYAL BAY PALM'],
        metadata: {
          type: 'residential',
          year_built: 2014,
          floors: 8,
          units: 196,
          developer: 'Nakheel'
        }
      },
      'ZABEEL SARAY' => {
        coords: [25.09849, 55.12360],
        aliases: ['ZABEEL SARAY', 'JUMEIRAH ZABEEL SARAY'],
        metadata: {
          type: 'hotel_residence',
          year_built: 2011,
          floors: 8,
          units: 405,
          developer: 'Jumeirah Group'
        }
      },
      'GRANDEUR RESIDENCES' => {
        coords: [25.098830, 55.121800],
        aliases: ['GRANDEUR RESIDENCES', 'GRANDUER RESIDENCES', 'GRANDEUR', 'GRANDUER'],
        metadata: {
          type: 'residential',
          year_built: 2012,
          floors: 30,
          units: 422,
          developer: 'Nakheel'
        }
      },
      # Shoreline Apartments sub-buildings (20 frond villas)
      'ABU KEIBAL' => {
        coords: [25.108179313750618, 55.14760196531019],
        aliases: ['ABU KEIBAL'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL ANBARA' => {
        coords: [25.112673171685934, 55.141749038749055],
        aliases: ['AL ANBARA', 'ANBARA'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL BASRI' => {
        coords: [25.10681403459865, 55.150934611202935],
        aliases: ['AL BASRI', 'BASRI', 'AL BASHRI', 'BASHRI'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL DABAS' => {
        coords: [25.107439968032086, 55.150215266781785],
        aliases: ['AL DABAS', 'DABAS'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL DAS' => {
        coords: [25.114107870674655, 55.14158893003817],
        aliases: ['AL DAS'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL HABOOL' => {
        coords: [25.113240308742526, 55.14081929392028],
        aliases: ['AL HABOOL', 'HABOOL'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL HALLAWI' => {
        coords: [25.11124883041989, 55.143418045111986],
        aliases: ['AL HALLAWI', 'HALLAWI'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL HAMRI' => {
        coords: [25.10665881650435, 55.14917838671534],
        aliases: ['AL HAMRI', 'HAMRI'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL HASEER' => {
        coords: [25.11208435336811, 55.14403562297922],
        aliases: ['AL HASEER', 'HASEER'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL HATIMI' => {
        coords: [25.109397977767692, 55.147578700950476],
        aliases: ['AL HATIMI', 'HATIMI'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL KHUDRAWI' => {
        coords: [25.110333539859983, 55.1467619432406],
        aliases: ['AL KHUDRAWI', 'KHUDRAWI'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL KHUSHKAR' => {
        coords: [25.10612936649333, 55.15011813219595],
        aliases: ['AL KHUSHKAR', 'KHUSHKAR'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL MSALLI' => {
        coords: [25.113328862816445, 55.142329445398886],
        aliases: ['AL MSALLI', 'MSALLI'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL NABAT' => {
        coords: [25.112696023429784, 55.143222154039165],
        aliases: ['AL NABAT', 'NABAT'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL SARROOD' => {
        coords: [25.111926485098046, 55.142553131766014],
        aliases: ['AL SARROOD', 'SARROOD'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL SHAHLA' => {
        coords: [25.108746734527138, 55.14646597731126],
        aliases: ['AL SHAHLA', 'SHAHLA'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL SULTANA' => {
        coords: [25.108118497298022, 55.149276422807134],
        aliases: ['AL SULTANA', 'SULTANA'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'AL TAMR' => {
        coords: [25.10917753606508, 55.14586232735876],
        aliases: ['AL TAMR', 'TAMR'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'JASH FALQA' => {
        coords: [25.108707734167837, 55.148390057430284],
        aliases: ['JASH FALQA'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      },
      'JASH HAMAD' => {
        coords: [25.107519004632035, 55.14850734832549],
        aliases: ['JASH HAMAD'],
        complex: 'SHORELINE APARTMENTS',
        metadata: { type: 'villa_community', developer: 'Nakheel' }
      }
    }
  end

  # ===============================================================
  # PUBLIC API - Location Detection
  # ===============================================================

  # Detect which location a listing is in based on coordinates
  # Returns location key (e.g. 'PALM_JUMEIRAH') or nil
  def self.detect_location(lat, lng)
    return nil if lat.nil? || lng.nil?
    
    LOCATIONS.each do |location_key, location_data|
      bounds = location_data[:bounds]
      if bounds[:lat].cover?(lat) && bounds[:lng].cover?(lng)
        return location_key
      end
    end
    
    nil
  end

  # Get human-readable location name
  def self.location_display_name(location)
    return nil unless location
    LOCATIONS[location]&.[](:display_name) || location.to_s.gsub('_', ' ').split.map(&:capitalize).join(' ')
  end

  # ===============================================================
  # PUBLIC API - Building Data Access
  # ===============================================================

  # Get all buildings for a specific location
  def self.buildings_for_location(location)
    return {} unless location
    LOCATIONS[location]&.[](:buildings) || {}
  end

  # Get all searchable aliases for a specific location
  def self.aliases_for_location(location)
    buildings = buildings_for_location(location)
    buildings.flat_map { |_, data| data[:aliases] }.uniq.sort_by { |a| -a.length }
  end

  # Get building metadata
  def self.building_metadata(building_name, location)
    buildings = buildings_for_location(location)
    buildings[building_name]&.[](:metadata)
  end

  # ===============================================================
  # PUBLIC API - Name Normalization
  # ===============================================================

  # Convert any alias to canonical building name within a location
  def self.normalize(matched_name, location)
    return nil if matched_name.nil? || matched_name.empty? || location.nil?
    
    buildings = buildings_for_location(location)
    matched_upper = matched_name.upcase.strip
    
    buildings.each do |canonical, data|
      if data[:aliases].any? { |alias_name| matched_upper == alias_name.upcase }
        return canonical
      end
    end
    
    nil
  end

  # ===============================================================
  # PUBLIC API - Coordinate Access
  # ===============================================================

  # Get coordinates for a building in a specific location
  def self.coordinates(building_name, location)
    return nil unless location
    buildings = buildings_for_location(location)
    buildings[building_name]&.[](:coords)
  end

  # ===============================================================
  # PUBLIC API - Complex Naming
  # ===============================================================

  # Get complex name if building is part of a larger complex
  def self.complex_name(building_name, location)
    return nil unless location
    buildings = buildings_for_location(location)
    buildings[building_name]&.[](:complex)
  end

  # Format building name with complex and location for display
  # Examples:
  #   "FIVE PALM JUMEIRAH, Palm Jumeirah"
  #   "MARINA RESIDENCES 1, MARINA RESIDENCES, Palm Jumeirah"
  #   "AL HAMRI, SHORELINE APARTMENTS, Palm Jumeirah"
  def self.format_full_name(building_name, location)
    return nil unless building_name && location
    
    complex = complex_name(building_name, location)
    location_display = location_display_name(location)
    
    if complex
      "#{building_name}, #{complex}, #{location_display}"
    else
      "#{building_name}, #{location_display}"
    end
  end

  # ===============================================================
  # PUBLIC API - Statistics & Validation
  # ===============================================================

  # Get total number of buildings in database
  def self.total_buildings_count
    LOCATIONS.sum { |_, location_data| location_data[:buildings].size }
  end

  # Get buildings count by location
  def self.buildings_count_by_location
    LOCATIONS.transform_values { |location_data| location_data[:buildings].size }
  end

  # Validate database integrity (run on initialization)
  def self.validate_database
    errors = []
    
    LOCATIONS.each do |location_key, location_data|
      # Validate bounds
      bounds = location_data[:bounds]
      if bounds[:lat].min >= bounds[:lat].max
        errors << "#{location_key}: Invalid latitude bounds"
      end
      if bounds[:lng].min >= bounds[:lng].max
        errors << "#{location_key}: Invalid longitude bounds"
      end
      
      # Validate buildings
      location_data[:buildings].each do |building_name, building_data|
        # Validate coordinates
        coords = building_data[:coords]
        if coords.nil? || coords.size != 2
          errors << "#{building_name}: Invalid coordinates"
        elsif !bounds[:lat].cover?(coords[0]) || !bounds[:lng].cover?(coords[1])
          errors << "#{building_name}: Coordinates outside location bounds"
        end
        
        # Validate aliases
        if building_data[:aliases].nil? || building_data[:aliases].empty?
          errors << "#{building_name}: No aliases defined"
        end
      end
    end
    
    if errors.any?
      puts "⚠️  Database validation errors found:"
      errors.each { |error| puts "   - #{error}" }
      false
    else
      puts "✅ Database validation passed (#{total_buildings_count} buildings)"
      true
    end
  end
end

# Validate database on load
BuildingDatabase.validate_database