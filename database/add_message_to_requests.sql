-- Add message column to collab_requests table
ALTER TABLE public.collab_requests 
ADD COLUMN IF NOT EXISTS message TEXT DEFAULT NULL;
