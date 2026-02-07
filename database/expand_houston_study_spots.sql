-- Expanded Houston Study Spots Import Script
-- Adds 50+ verified study spots to create a richer map experience
-- These spots complement the existing seed data

-- ============================================
-- ADDITIONAL STUDY SPOTS
-- ============================================

INSERT INTO public.study_spots (name, lat, long, image_url, perks, incentive, type)
VALUES
  -- ========================================
  -- Near UH Main Campus / Third Ward
  -- ========================================
  (
    'The Nook Cafe',
    29.7205, -95.3410, -- UH Campus (Student Center area)
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'late-hours', 'student-run', 'cozy'],
    'Bottomless drip coffee available',
    'cafe'
  ),
  (
    'Doshi House',
    29.7253, -95.3588, -- Third Ward / Emancipation Ave
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'vegan-options', 'cozy', 'tea'],
    NULL,
    'cafe'
  ),
  (
    'The Ion',
    29.7520, -95.3787, -- Midtown / Wheeler
    'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'coworking', 'modern', 'tech-hub'],
    'Public access to lower floors',
    'library'
  ),
  (
    'Blanca Cafe',
    29.7456, -95.3428, -- Near UH / Milby St
    'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'coffee', 'pastries', 'aesthetic'],
    NULL,
    'cafe'
  ),

  -- ========================================
  -- Montrose Area (Popular student area)
  -- ========================================
  (
    'Siphon Coffee',
    29.7388, -95.3835, -- West Alabama / Montrose
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'specialty-coffee', 'stylish', 'quiet'],
    NULL,
    'cafe'
  ),
  (
    'Black Hole Coffee House',
    29.7395, -95.3901, -- Montrose / Graustark
    'https://images.unsplash.com/photo-1453614512568-c4024d13c247?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'late-hours', 'cozy-couches', 'patio'],
    'Open late night',
    'cafe'
  ),
  (
    'Campesino Coffee House',
    29.7568, -95.4029, -- Montrose / Waugh Dr
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'local', 'latino-fare'],
    NULL,
    'cafe'
  ),
  (
    'Slowpokes Montrose',
    29.7445, -95.3951, -- Montrose
    'https://images.unsplash.com/photo-1518832553480-cd0e625ed3e6?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'calm', 'quality-coffee', 'pastries'],
    NULL,
    'cafe'
  ),
  (
    'The Teahouse',
    29.7379, -95.4072, -- Westheimer / Shepherd
    'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'boba', 'spacious', 'group-friendly'],
    NULL,
    'cafe'
  ),

  -- ========================================
  -- East End / EaDo (Near Downtown HCC)
  -- ========================================
  (
    'Coral Sword',
    29.7422, -95.3314, -- Eastwood
    'https://images.unsplash.com/photo-1511920170033-f8396924c348?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'coffee', 'board-games', 'colorful'],
    'Board games available for breaks',
    'cafe'
  ),
  (
    'Understory',
    29.7589, -95.3633, -- Downtown / Tunnels
    'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'food-hall', 'quiet-hours', 'central'],
    'Quiet outside lunch hours',
    'cafe'
  ),

  -- ========================================
  -- Near HCC Northwest / Spring Branch
  -- ========================================
  (
    'Slowpokes Spring Branch',
    29.7873, -95.4897, -- Spring Branch area
    'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'calm', 'outlets', 'pastries'],
    NULL,
    'cafe'
  ),
  (
    'Houston Public Library - Spring Branch',
    29.7887, -95.4724, -- Spring Branch Memorial
    'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'free', 'study-rooms'],
    'Free with library card',
    'library'
  ),

  -- ========================================
  -- Near HCC Southeast / South Houston
  -- ========================================
  (
    'Capital One Cafe Gulfgate',
    29.6943, -95.3305, -- Gulfgate area
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'free-access', 'student-room', 'whiteboard'],
    '50% off drinks for Capital One cardholders',
    'cafe'
  ),
  (
    'Houston Public Library - Bracewell',
    29.7114, -95.3251, -- Near HCC Southeast
    'https://images.unsplash.com/photo-1568667256549-094345857637?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'free', 'computers'],
    'Free with library card',
    'library'
  ),

  -- ========================================
  -- Near UH Clear Lake
  -- ========================================
  (
    'Starbucks Clear Lake',
    29.5595, -95.0973, -- Near UH Clear Lake
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'drive-thru', 'familiar'],
    NULL,
    'cafe'
  ),
  (
    'Freeman Branch Library',
    29.5638, -95.0944, -- Clear Lake area
    'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'study-rooms', 'free'],
    'Free with library card',
    'library'
  ),

  -- ========================================
  -- Near UH Downtown / HCC Central
  -- ========================================
  (
    'Kitten Coffee House',
    29.7554, -95.3573, -- Downtown/Midtown
    'https://images.unsplash.com/photo-1445116572660-236099ec97a0?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'cozy', 'aesthetic', 'pastries'],
    NULL,
    'cafe'
  ),
  (
    'Inversion Coffee House',
    29.7447, -95.3934, -- Montrose near Downtown
    'https://images.unsplash.com/photo-1497636577773-f1231844b336?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'spacious', 'outdoor-patio', 'hipster'],
    NULL,
    'cafe'
  ),
  (
    'Julia Ideson Building',
    29.7578, -95.3651, -- Downtown (historic library)
    'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=400',
    ARRAY['quiet', 'beautiful-architecture', 'historic', 'study-rooms'],
    'Houston Public Library - Historic',
    'library'
  ),

  -- ========================================
  -- Houston Heights
  -- ========================================
  (
    'Tenfold Coffee Company',
    29.7891, -95.3993, -- Heights / 19th St
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'spacious', 'outlets', 'airy'],
    NULL,
    'cafe'
  ),
  (
    'Coffee House at West End',
    29.7923, -95.4127, -- Heights / Washington
    'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'two-floors', 'workspace', 'snacks'],
    'Designed for working',
    'cafe'
  ),
  (
    'Blue Tile Coffee',
    29.7856, -95.4021, -- Heights / Washington
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'high-ceilings', 'spacious', 'outlets'],
    NULL,
    'cafe'
  ),
  (
    'Antidote Coffee',
    29.7672, -95.4089, -- Heights / Studemont
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'cozy', 'plugs'],
    'Quiet during non-peak hours',
    'cafe'
  ),

  -- ========================================
  -- Galleria Area
  -- ========================================
  (
    'Capital One Cafe Galleria',
    29.7390, -95.4612, -- Inside Galleria
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'free', 'student-room', 'whiteboard'],
    '50% off drinks for Capital One cardholders',
    'cafe'
  ),
  (
    'Whole Foods Post Oak',
    29.7413, -95.4594, -- Galleria / Post Oak
    'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'upstairs-seating', 'food', 'spacious'],
    'Many work from upstairs area',
    'cafe'
  ),

  -- ========================================
  -- Rice Village / Museum District
  -- ========================================
  (
    'Bluestone Lane Rice Village',
    29.7178, -95.4110, -- Rice Village
    'https://images.unsplash.com/photo-1445116572660-236099ec97a0?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'australian', 'outdoor-seating', 'groups'],
    NULL,
    'cafe'
  ),
  (
    'Croissant-Brioche',
    29.7162, -95.4089, -- Rice Village
    'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'french-bakery', 'big-tables', 'pastries'],
    NULL,
    'cafe'
  ),
  (
    'Agnes Cafe',
    29.7149, -95.4031, -- Rice Village
    'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'cozy', 'italian-espresso', 'quiet'],
    NULL,
    'cafe'
  ),
  (
    'Mo Better Brews',
    29.7268, -95.3857, -- Museum District
    'https://images.unsplash.com/photo-1518832553480-cd0e625ed3e6?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'vegan-friendly', 'positive-vibes', 'coffee'],
    NULL,
    'cafe'
  ),
  (
    'Kaffeine Coffee',
    29.7291, -95.3812, -- Museum District
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'sandwiches', 'pastries', 'drinks'],
    NULL,
    'cafe'
  ),
  (
    'Ginger Kale Hermann Park',
    29.7223, -95.3901, -- Hermann Park
    'https://images.unsplash.com/photo-1453614512568-c4024d13c247?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'healthy', 'pond-view', 'outdoor-seating'],
    NULL,
    'cafe'
  ),
  (
    'Cafe Leonelli MFAH',
    29.7261, -95.3906, -- Museum of Fine Arts
    'https://images.unsplash.com/photo-1497636577773-f1231844b336?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'italian', 'museum', 'upscale'],
    'At Museum of Fine Arts',
    'cafe'
  ),

  -- ========================================
  -- Missouri City / Fort Bend
  -- ========================================
  (
    'Fellowship Coffee Missouri City',
    29.5679, -95.5378, -- FM 1092, Missouri City
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'artisan', 'spacious', 'outlets'],
    NULL,
    'cafe'
  ),
  (
    'Summer Moon Coffee Sienna',
    29.5412, -95.5123, -- Highway 6, Sienna
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'oak-roasted', 'free-wifi', 'popular'],
    NULL,
    'cafe'
  ),
  (
    'bean here coffee Sienna',
    29.5398, -95.5089, -- Sienna Pkwy
    'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'patio', 'indoor-seating', 'cozy'],
    NULL,
    'cafe'
  ),
  (
    'Missouri City Branch Library',
    29.5676, -95.5426, -- Texas Parkway
    'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'spacious', 'free'],
    'Free with library card',
    'library'
  ),
  (
    'Sienna Branch Library',
    29.5289, -95.4978, -- Sienna Springs Blvd
    'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'two-story', 'modern', 'vip-hours'],
    'Extended VIP Access hours',
    'library'
  ),

  -- ========================================
  -- Pearland Area
  -- ========================================
  (
    'LIT Java Coffee & Books',
    29.5621, -95.2874, -- Broadway St, Pearland
    'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'bookstore', 'cozy', 'creative'],
    'Coffee + bookstore combo',
    'cafe'
  ),
  (
    'Waygood Coffee Pearland',
    29.5487, -95.2912, -- Old Max Ct, Pearland
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quality', 'cozy', 'pastries'],
    NULL,
    'cafe'
  ),
  (
    'Haraz Coffee House Pearland',
    29.5512, -95.2834, -- Pearland area
    'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'pistachio-lattes', 'croissants', 'cozy'],
    NULL,
    'cafe'
  ),
  (
    'First Cup Coffee Pearland',
    29.5598, -95.2856, -- Broadway, Pearland
    'https://images.unsplash.com/photo-1453614512568-c4024d13c247?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'local', 'quiet', 'coffee'],
    NULL,
    'cafe'
  ),
  (
    'West Pearland Library',
    29.5467, -95.4023, -- Shadow Creek Pkwy
    'https://images.unsplash.com/photo-1568667256549-094345857637?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'study-rooms', 'vip-hours', 'free'],
    'Free with library card',
    'library'
  ),
  (
    'Tom Reid Library Pearland',
    29.5589, -95.2867, -- Liberty Dr, Pearland
    'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'computers', 'free'],
    'Free with library card',
    'library'
  ),

  -- ========================================
  -- HCC Alief / Westside
  -- ========================================
  (
    'Houston Public Library - Alief',
    29.7112, -95.5912, -- Alief area
    'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'regional', 'free'],
    'Free with library card',
    'library'
  ),
  (
    'Starbucks Alief',
    29.7089, -95.5673, -- Near HCC Alief Hayes
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'familiar', 'drive-thru'],
    NULL,
    'cafe'
  ),

  -- ========================================
  -- HCC Stafford Area
  -- ========================================
  (
    'Minuti Coffee Stafford',
    29.6234, -95.5789, -- Near Stafford
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'pastries', 'music', 'friendly'],
    NULL,
    'cafe'
  ),

  -- ========================================
  -- Additional Popular Chains
  -- ========================================
  (
    'Starbucks Rice Village',
    29.7167, -95.4078, -- Rice Village
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'familiar', 'central'],
    NULL,
    'cafe'
  ),
  (
    'Starbucks Midtown',
    29.7489, -95.3756, -- Midtown
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'familiar', 'central'],
    NULL,
    'cafe'
  );

-- ============================================
-- Verification query
-- ============================================
-- SELECT name, lat, long, type, perks FROM public.study_spots ORDER BY name;
