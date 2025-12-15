-- Create Study Spots Table
create table if not exists public.study_spots (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  -- We include separate lat/long for easy frontend access, 
  -- and a PostGIS column for efficient spatial queries (future proofing)
  lat double precision not null,
  long double precision not null,
  location geography(point) generated always as (st_point(long, lat)::geography) stored,
  image_url text,
  perks text[] default '{}', -- e.g. ['wifi', 'outlets', 'quiet']
  incentive text, -- e.g. "10% off for students"
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.study_spots enable row level security;

-- Policy: Everyone can view study spots
create policy "Study spots are viewable by everyone"
  on public.study_spots for select
  using (true);

-- SEED DATA (NYC Area - near default map center 40.7128, -74.0060)
insert into public.study_spots (name, lat, long, image_url, perks, incentive)
values
  (
    'The Code Cafe',
    40.7128, -74.0060, -- Exact Center
    'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=400',
    array['wifi', 'outlets', 'coffee'],
    '10% off with Student ID'
  ),
  (
    'Library Lofts',
    40.7140, -74.0080, -- Slightly North West
    'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=400',
    array['quiet', 'large_tables', 'free_wifi'],
    null
  ),
  (
    'Cyber Brew',
    40.7110, -74.0040, -- South East
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=400',
    array['wifi', '24_7', 'snacks'],
    'Free Espresso Shot'
  ),
  (
    'Nerd Herd HQ',
    40.7115, -74.0090, -- South West
    'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=400',
    array['fast_wifi', 'monitors', 'group_rooms'],
    'Free Day Pass'
  ),
  (
    'Skyline Study',
    40.7150, -74.0020, -- North East
    'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=400',
    array['view', 'quiet', 'expensive_coffee'],
    'Happy Hour 2-5PM'
  );
