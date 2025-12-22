-- Seed check to prevent duplicates
DO $$
DECLARE
    uni_id uuid;
BEGIN
    -- 1. Insert Hogwarts if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM universities WHERE name = 'Hogwarts School of Witchcraft and Wizardry') THEN
        INSERT INTO universities (name, domain, logo_url)
        VALUES (
            'Hogwarts School of Witchcraft and Wizardry',
            'hogwarts.edu',
            'https://github.com/user-attachments/assets/hogwarts_icon_placeholder.jpg' -- Placeholder, requires real URL hosting or Supabase Storage
        )
        RETURNING id INTO uni_id;
    ELSE
        SELECT id INTO uni_id FROM universities WHERE name = 'Hogwarts School of Witchcraft and Wizardry';
    END IF;

    -- 2. Insert Courses
    -- Potions
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'POTIONS101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'POTIONS101', 'Potions', 'Year 1');
    END IF;

    -- DADA
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'DADA101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'DADA101', 'Defense Against the Dark Arts', 'Year 1');
    END IF;

    -- Charms
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'CHARMS101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'CHARMS101', 'Charms', 'Year 1');
    END IF;

    -- Transfiguration
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'TRANS101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'TRANS101', 'Transfiguration', 'Year 1');
    END IF;

    -- Herbology
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'HERB101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'HERB101', 'Herbology', 'Year 1');
    END IF;

    -- Astronomy
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'ASTRO101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'ASTRO101', 'Astronomy', 'Year 1');
    END IF;

    -- History of Magic
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'HISTM101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'HISTM101', 'History of Magic', 'Year 1');
    END IF;

    -- Flying
    IF NOT EXISTS (SELECT 1 FROM courses WHERE university_id = uni_id AND code = 'FLY101') THEN
        INSERT INTO courses (university_id, code, title, term) VALUES (uni_id, 'FLY101', 'Flying', 'Year 1');
    END IF;

END $$;
