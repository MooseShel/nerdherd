-- Create SESSIONS table to track verified interactions
-- This table is the source of truth for "Tutor-Confirmed" interactions.
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tutor_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    source TEXT DEFAULT 'manual' CHECK (source IN ('manual', 'payment')), -- Future proofing for payments
    
    -- Constraint: Prevent duplicate sessions for the same pair quickly? 
    -- For now, allow multiple sessions as they might have multiple classes.
    CONSTRAINT sessions_participants_check CHECK (tutor_id != student_id)
);

-- RLS for Sessions
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Tutors can insert sessions where THEY are the tutor
CREATE POLICY "Tutors can log sessions"
    ON public.sessions FOR INSERT
    WITH CHECK (auth.uid() = tutor_id);

-- Students (and Tutors) can view their own sessions
CREATE POLICY "Users can view their own sessions"
    ON public.sessions FOR SELECT
    USING (auth.uid() = tutor_id OR auth.uid() = student_id);

-- Payment System (Service Role) will bypass RLS to insert 'payment' source sessions later.


-- Create RATINGS table (or update if exists)
CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rater_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE, -- Student
    rated_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE, -- Tutor
    session_id UUID REFERENCES public.sessions(id) ON DELETE SET NULL, -- Link to proof
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    
    UNIQUE(session_id)
);

-- Ensure session_id column exists (in case table already existed without it)
ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES public.sessions(id) ON DELETE SET NULL;

-- Ensure Unique Constraint on session_id
-- Safely handle constraint:
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ratings_session_id_key') THEN
        ALTER TABLE public.ratings ADD CONSTRAINT ratings_session_id_key UNIQUE (session_id);
    END IF;
END $$;


-- RLS for Ratings
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to ensure clean state
DROP POLICY IF EXISTS "Public read ratings" ON public.ratings;
DROP POLICY IF EXISTS "Students with session can rate" ON public.ratings;

-- Public read
CREATE POLICY "Public read ratings"
    ON public.ratings FOR SELECT
    USING (true);

-- Authenticated Insert: MUST have a valid session where (rater=student, rated=tutor)
CREATE POLICY "Students with session can rate"
    ON public.ratings FOR INSERT
    WITH CHECK (
        auth.uid() = rater_id AND
        EXISTS (
            SELECT 1 FROM public.sessions s
            WHERE s.id = session_id
            AND s.student_id = rater_id
            AND s.tutor_id = rated_id
        )
    );

-- Realtime (Safe Update)
DO $$
BEGIN
  -- Add sessions if not present
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'sessions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.sessions;
  END IF;

  -- Add ratings if not present
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'ratings') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ratings;
  END IF;
END $$;
