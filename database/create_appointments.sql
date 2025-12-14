-- Create Appointments Table
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE, -- Tutor
    attendee_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE, -- Student
    
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'declined', 'cancelled', 'completed')),
    message TEXT, -- Initial request message
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- RLS
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Policy: View own appointments (as host or attendee)
CREATE POLICY "View own appointments"
    ON public.appointments FOR SELECT
    USING (auth.uid() = host_id OR auth.uid() = attendee_id);

-- Policy: Insert appointment (Anyone can request, usually attendee)
CREATE POLICY "Make appointment request"
    ON public.appointments FOR INSERT
    WITH CHECK (auth.uid() = attendee_id);

-- Policy: Update own appointments
-- Hosts can update status (Accept/Decline)
-- Attendees can Cancel
CREATE POLICY "Update own appointments"
    ON public.appointments FOR UPDATE
    USING (auth.uid() = host_id OR auth.uid() = attendee_id);

-- Realtime
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'appointments') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.appointments;
  END IF;
END $$;
