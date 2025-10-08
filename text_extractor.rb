# text_extractor.rb
# ENTERPRISE-GRADE building name extraction for Dubai real estate
# Built to handle 1000+ buildings across all Dubai areas

require_relative 'building_database'

module TextExtractor
  # Exclusion patterns - phrases that indicate it's NOT in the building
  EXCLUSION_PATTERNS = [
    # View/Proximity indicators
    /view(?:s)?\s+(?:of|over|to|towards|across|onto|on)\s+/i,
    /overlooking\s+(?:the\s+)?/i,
    /facing\s+(?:the\s+)?/i,
    /close\s+(?:proximity\s+)?to\s+/i,
    /near(?:by)?\s+(?:to\s+)?(?:the\s+)?/i,
    /walking\s+distance\s+(?:to|from)\s+/i,
    /minutes?\s+(?:from|to|away|walk)\s+/i,
    /proximity\s+to\s+/i,
    /access\s+to\s+/i,
    /next\s+to\s+/i,
    /opposite\s+/i,
    /across\s+from\s+/i,
    /short\s+(?:walk|drive|distance)\s+(?:to|from)\s+/i,
    
    # Tourism/Activity indicators
    /perfect\s+for\s+visiting\s+/i,
    /explore\s+/i,
    /visit\s+/i,
    /iconic\s+/i,
    
    # Comparison/Metaphor indicators
    /like\s+(?:a|an|the)\s+/i,
    /similar\s+to\s+/i,
    /reminiscent\s+of\s+/i,
    /(?:a|an|your|the)\s+\w+\s+dream/i,  # "a dream vacation", "your dream home"
    /as\s+(?:good|nice|beautiful|luxurious)\s+as\s+/i
  ].freeze

  # Extract building name from text for a specific location
  def self.extract(text, location)
    return [nil, nil] if text.nil? || text.empty? || location.nil?

    patterns = build_comprehensive_patterns(location)
    best_match = find_best_match(text, patterns)

    return [nil, nil] unless best_match

    # Normalize to canonical name within this location
    canonical = BuildingDatabase.normalize(best_match[:building], location)
    return [nil, nil] unless canonical

    # Format with complex and location
    formatted = BuildingDatabase.format_full_name(canonical, location)
    
    [formatted, best_match[:confidence]]
  end

  private

  # Build comprehensive pattern system covering ALL possible phrasings
  def self.build_comprehensive_patterns(location)
    aliases = BuildingDatabase.aliases_for_location(location)
    return [] if aliases.empty?
    
    # Sort aliases by length (longest first) to match specific names before generic
    aliases = aliases.sort_by { |a| -a.length }
    long_aliases = aliases.select { |a| a.length > 6 }

    patterns = []

    # ==================================================================
    # TIER 0: EXPLICIT LOCATION STATEMENTS (Priority 0)
    # "I am located in/at X" - Strongest possible signal
    # ==================================================================
    
    # Special cases for major complexes
    patterns << { 
      regex: /\b(?:in|at|within|nestled\s+in)\s+(?:the\s+)?(?:vibrant\s+)?(EMAAR BEACHFRONT)\s+community/i,
      confidence: 'high', priority: 0 
    }
    
    patterns << {
      regex: /\b(MARINA VISTA|SUNRISE BAY|BEACH ISLE|BEACH VISTA|GRAND BLEU|PALACE BEACH)\s+(?:TOWER|BUILDING)\s+\d+/i,
      confidence: 'high', priority: 0
    }
    
    patterns << {
      regex: /\bneighbor(?:ing|s)\s+(?:our\s+)?(?:residency|residence|building)\s+is\s+(?:a\s+)?(?:famous\s+)?(?:5-star\s+)?(?:hotel\s+)?(ZABEEL\s+SARAY)/i,
      confidence: 'high', priority: 0
    }

    # "located/situated at/in [BUILDING]"
    if !long_aliases.empty?
      patterns << {
        regex: /\b(?:located|situated|residing|based|positioned)\s+(?:at|in|within)\s+(?:the\s+)?(?:residences\s+of\s+(?:the\s+)?)?(?:luxurious\s+)?(#{long_aliases.map { |a| Regexp.escape(a) }.join('|')})/i,
        confidence: 'high', priority: 0
      }
    end

    # "[BUILDING] offers occupants" - Strong ownership language
    patterns << {
      regex: /\b(TIARA RESIDENCES?)\s+offers?\s+(?:occupants|residents|guests)/i,
      confidence: 'high', priority: 0
    }

    # ==================================================================
    # TIER 1: TITLE/DESCRIPTION LOCATION PHRASES (Priority 0)
    # "at X", "in X", "within X" - Common in titles
    # ==================================================================
    
    LOCATION_PREPOSITIONS = ['at', 'in', 'within', 'inside']
    
    LOCATION_PREPOSITIONS.each do |prep|
      aliases.each do |building_alias|
        patterns << {
          regex: /\b#{prep}\s+(#{Regexp.escape(building_alias)})\b/i,
          confidence: 'high',
          priority: 0
        }
      end
    end

    # ==================================================================
    # TIER 2: PROPERTY TYPE + LOCATION (Priority 1)
    # "apartment in X", "studio at X", "penthouse within X"
    # ==================================================================
    
    PROPERTY_TYPES = [
      'apartment', 'unit', 'flat', 'penthouse', 'studio',
      'home', 'residence', 'property', 'accommodation'
    ]
    
    PROPERTY_TYPES.each do |prop_type|
      LOCATION_PREPOSITIONS.each do |prep|
        aliases.each do |building_alias|
          patterns << {
            regex: /\b#{prop_type}\s+#{prep}\s+(?:the\s+)?(#{Regexp.escape(building_alias)})\b/i,
            confidence: 'high',
            priority: 1
          }
        end
      end
    end

    # ==================================================================
    # TIER 3: BUILDING AS SUBJECT (Priority 1)
    # "[BUILDING] is a/an/the", "[BUILDING] features", "[BUILDING] provides"
    # ==================================================================
    
    SUBJECT_VERBS = ['is', 'was', 'features', 'provides', 'offers', 'boasts', 'includes']
    
    SUBJECT_VERBS.each do |verb|
      aliases.each do |building_alias|
        patterns << {
          regex: /\b(#{Regexp.escape(building_alias)})\s+#{verb}\s+(?:a|an|the)\b/i,
          confidence: 'high',
          priority: 1
        }
      end
    end

    # ==================================================================
    # TIER 4: BUILDING WITH LOCATION SUFFIX (Priority 2)
    # "[BUILDING] - Palm Jumeirah", "[BUILDING], Dubai"
    # ==================================================================
    
    aliases.each do |building_alias|
      patterns << {
        regex: /\b(#{Regexp.escape(building_alias)})\s*[-–,]\s*(?:Palm\s+Jumeirah|Dubai|UAE)/i,
        confidence: 'high',
        priority: 2
      }
    end

    # ==================================================================
    # TIER 5: POSSESSIVE/DESCRIPTIVE (Priority 2)
    # "the [BUILDING]'s facilities", "[BUILDING] residents", "our [BUILDING] apartment"
    # ==================================================================
    
    POSSESSIVE_INDICATORS = ['the', 'our', 'their', 'this', 'these']
    
    POSSESSIVE_INDICATORS.each do |indicator|
      aliases.each do |building_alias|
        patterns << {
          regex: /\b#{indicator}\s+(#{Regexp.escape(building_alias)})(?:'s|\s+(?:residents|facilities|apartments|units))/i,
          confidence: 'medium',
          priority: 2
        }
      end
    end

    # ==================================================================
    # TIER 6: STANDALONE EXACT MATCH (Priority 3)
    # Just the building name appearing in text
    # Exclude commonly false-positive buildings (Atlantis, Dream)
    # ==================================================================
    
    aliases.reject { |a| a.match?(/ATLANTIS|DREAM/i) }.each do |building_alias|
      patterns << {
        regex: /\b(#{Regexp.escape(building_alias)})\b/i,
        confidence: 'medium',
        priority: 3
      }
    end

    # ==================================================================
    # TIER 7: DEPRIORITIZED BUILDINGS (Priority 5)
    # Buildings that are often mentioned for views/proximity
    # ==================================================================
    
    patterns << { regex: /\b(ATLANTIS THE PALM|ATLANTIS)\b/i, confidence: 'low', priority: 5 }
    patterns << { regex: /\b(ROYAL ATLANTIS)\b/i, confidence: 'low', priority: 5 }
    patterns << { regex: /\b(DREAM PALM|DREAM)\b/i, confidence: 'low', priority: 5 }
    patterns << { regex: /\b(BURJ AL ARAB)\b/i, confidence: 'low', priority: 5 }
    patterns << { regex: /\b(BURJ KHALIFA)\b/i, confidence: 'low', priority: 5 }

    # Sort by priority (lower number = higher priority)
    patterns.sort_by { |p| p[:priority] }
  end

  # Find best matching pattern with exclusion filtering
  def self.find_best_match(text, patterns)
    best_match = nil
    best_priority = 999
    all_matches = []

    patterns.each do |pattern|
      text.to_enum(:scan, pattern[:regex]).each do |match_data|
        full_match = Regexp.last_match
        building = full_match[1].strip

        # Store all matches for debugging
        match_info = {
          building: building,
          confidence: pattern[:confidence],
          priority: pattern[:priority],
          position: full_match.begin(0),
          excluded: false
        }

        # Check exclusion context
        if in_exclusion_context?(text, full_match.begin(0))
          match_info[:excluded] = true
          all_matches << match_info
          next
        end

        all_matches << match_info

        # Keep highest priority match (lowest number wins)
        if pattern[:priority] < best_priority
          best_match = {
            building: building,
            confidence: pattern[:confidence],
            priority: pattern[:priority]
          }
          best_priority = pattern[:priority]
        end
      end
    end

    # Debug output for complex cases
    if all_matches.size > 3
      puts "      📊 Found #{all_matches.size} potential matches (showing top 5):"
      all_matches.sort_by { |m| m[:priority] }.first(5).each do |m|
        status = m[:excluded] ? '❌ EXCLUDED' : (m[:building] == best_match[:building] ? '✅ SELECTED' : '⚪ SKIPPED')
        puts "         #{status}: #{m[:building]} (priority: #{m[:priority]})"
      end
    end

    best_match
  end

  # Check if match appears in exclusion context
  def self.in_exclusion_context?(text, match_position)
    context_start = [match_position - 150, 0].max
    context_before = text[context_start...match_position]

    EXCLUSION_PATTERNS.any? { |pattern| context_before.match?(pattern) }
  end
end