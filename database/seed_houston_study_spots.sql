-- Houston Area Study Spots Import Script
-- Removes NYC seed data and adds verified study spots near UH and HCC campuses

-- ============================================
-- STEP 1: Remove existing NYC seed data
-- ============================================
DELETE FROM public.study_spots 
WHERE name IN ('The Code Cafe', 'Library Lofts', 'Cyber Brew', 'Nerd Herd HQ', 'Skyline Study');

-- ============================================
-- STEP 2: Insert Houston-area study spots
-- ============================================

INSERT INTO public.study_spots (name, lat, long, image_url, perks, incentive, type)
VALUES
  -- ========================================
  -- Near UH Main Campus (Third Ward area)
  -- ========================================
  (
    'Cougar Grounds',
    29.7199, -95.3422, -- UH Student Center
    'https://images.unsplash.com/photo-1559305616-3f99cd43e353?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'student-run', 'coffee'],
    '10% off with UH ID',
    'cafe'
  ),
  (
    'Segundo Coffee Lab',
    29.7456, -95.3428, -- 711 Milby St, Houston TX 77023
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'spacious', 'industrial'],
    NULL,
    'cafe'
  ),
  (
    'MD Anderson Library',
    29.7214, -95.3434, -- UH Main Campus
    'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'study-rooms', 'computers'],
    'Free for UH students',
    'library'
  ),

  -- ========================================
  -- Near HCC Central / Downtown / UH Downtown
  -- ========================================
  (
    'Tout Suite',
    29.7525, -95.3663, -- 1515 Fannin St, Houston TX 77002
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'large-space', 'diverse-menu', 'late-hours'],
    NULL,
    'cafe'
  ),
  (
    'Agora',
    29.7439, -95.3929, -- 1712 Westheimer Rd, Houston TX 77098
    'https://images.unsplash.com/photo-1445116572660-236099ec97a0?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'late-hours', 'affordable', 'cozy'],
    'Open until 2AM',
    'cafe'
  ),
  (
    'Brass Tacks',
    29.7502, -95.3521, -- East Downtown (EaDo)
    'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'spacious', 'outlets', 'group-friendly'],
    NULL,
    'cafe'
  ),
  (
    'Houston Public Library - Central',
    29.7579, -95.3634, -- 500 McKinney St, Houston TX 77002
    'https://images.unsplash.com/photo-1568667256549-094345857637?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'free', 'computers'],
    'Free with library card',
    'library'
  ),
  (
    'HCC Central Campus Learning Hub',
    29.7285, -95.3769, -- 1300 Holman St, Houston TX 77004
    'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'computers', 'study-rooms'],
    'Free for HCC students',
    'library'
  ),

  -- ========================================
  -- Near UH Sugar Land
  -- ========================================
  (
    'Fort Bend County Library - University Branch',
    29.6198, -95.6349, -- Near UH Sugar Land campus
    'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'adjacent-to-campus', 'free'],
    'Free with library card',
    'library'
  ),
  (
    'BlendIn Coffee Club',
    29.5927, -95.6195, -- Sugar Land area
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'quiet', 'aesthetic'],
    NULL,
    'cafe'
  ),
  (
    'Qahwah House',
    29.5823, -95.6244, -- Sugar Land
    'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'spacious', 'authentic-coffee', 'outlets'],
    NULL,
    'cafe'
  ),
  (
    'Minuti Coffee',
    29.5746, -95.6092, -- Highway 6, Sugar Land
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'quiet', 'coffee', 'pastries'],
    NULL,
    'cafe'
  ),

  -- ========================================
  -- Near UH Katy / HCC Katy
  -- ========================================
  (
    'Black Rock Coffee Bar - Katy',
    29.7856, -95.7578, -- Katy area
    'https://images.unsplash.com/photo-1518832553480-cd0e625ed3e6?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'outlets', 'tables', 'drive-thru'],
    NULL,
    'cafe'
  ),
  (
    'Coffee Fellows',
    29.7912, -95.7245, -- Hwy 99 near Clay Rd, Katy
    'https://images.unsplash.com/photo-1453614512568-c4024d13c247?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'nice-interior', 'outlets', 'quiet'],
    NULL,
    'cafe'
  ),
  (
    'Cocohodo',
    29.7723, -95.7412, -- Mason Rd, Katy
    'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=400',
    ARRAY['wifi', 'popular', 'coffee', 'cozy'],
    NULL,
    'cafe'
  );

-- ============================================
-- Verification query
-- ============================================
-- SELECT name, lat, long, type, perks FROM public.study_spots ORDER BY name;
