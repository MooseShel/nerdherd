-- Enable pgvector extension for semantic search
CREATE EXTENSION IF NOT EXISTS vector;

-- Add study style fields to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS bio_embedding vector(1536), -- Dimension for text-embedding-004 or similar
ADD COLUMN IF NOT EXISTS study_style_social float DEFAULT 0.5, -- 0.0 (Silent) to 1.0 (Social)
ADD COLUMN IF NOT EXISTS study_style_temporal float DEFAULT 0.5; -- 0.0 (Morning) to 1.0 (Night)

-- Create HNSW index for fast similarity search
-- Note: ivfflat is also an option, but HNSW is generally better for dynamic data
CREATE INDEX IF NOT EXISTS idx_profiles_bio_embedding ON public.profiles 
USING hnsw (bio_embedding vector_cosine_ops);
