-- University Schema

create table public.universities (
  id uuid not null default gen_random_uuid(),
  name text not null,
  domain text,
  logo_url text,
  created_at timestamptz default now(),
  constraint universities_pkey primary key (id)
);

create table public.courses (
  id uuid not null default gen_random_uuid(),
  university_id uuid not null references public.universities(id) on delete cascade,
  code text not null, -- e.g. "CS101"
  title text not null, -- e.g. "Intro to CS"
  term text, -- e.g. "Fall 2025"
  created_at timestamptz default now(),
  constraint courses_pkey primary key (id)
);

create table public.enrollments (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  created_at timestamptz default now(),
  constraint enrollments_pkey primary key (user_id, course_id)
);

-- RLS Policies
alter table public.universities enable row level security;
alter table public.courses enable row level security;
alter table public.enrollments enable row level security;

-- Public read access for universities and courses
create policy "Universities are viewable by everyone" on public.universities
  for select using (true);

create policy "Courses are viewable by everyone" on public.courses
  for select using (true);

-- Enrollments: Users can view their own, insert their own, delete their own
create policy "Users can view own enrollments" on public.enrollments
  for select using (auth.uid() = user_id);

create policy "Users can enroll themselves" on public.enrollments
  for insert with check (auth.uid() = user_id);

create policy "Users can unenroll themselves" on public.enrollments
  for delete using (auth.uid() = user_id);

-- Seed Data (Simulation)
insert into public.universities (name, domain, logo_url) values 
('Nerd Herd University', 'nerdherd.edu', 'assets/images/nerd_herd_logo.png');

-- (Note: You'd typically need the UUID of the inserted university to seed courses, 
-- but we'll handle seeding dynamically in the app if needed or assumes user adds them manually in admin later)
