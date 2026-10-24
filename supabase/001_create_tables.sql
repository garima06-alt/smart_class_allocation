-- Part 3.3: create the 11 schema tables in dependency order.

-- Academic branches (IT, CSE, CE, AIM).
CREATE TABLE IF NOT EXISTS public.branches (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL,
  code text NOT NULL
);

-- Academic years 1-4 (FY, SY, TY, LY).
CREATE TABLE IF NOT EXISTS public.academic_years (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  year_number smallint NOT NULL,
  name text NOT NULL,
  code text NOT NULL
);

-- App user profiles; id matches the Supabase Auth user.
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  email text NOT NULL,
  role text NOT NULL,
  branch_id bigint REFERENCES public.branches (id),
  can_approve boolean NOT NULL DEFAULT false
);

-- Physical classrooms and labs (added later by an admin).
CREATE TABLE IF NOT EXISTS public.rooms (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room_number text NOT NULL,
  building text NOT NULL,
  floor integer NOT NULL,
  capacity integer NOT NULL,
  room_type text NOT NULL,
  status text NOT NULL DEFAULT 'active'
);

-- Facilities that rooms may provide (projector, computers, etc.).
CREATE TABLE IF NOT EXISTS public.facilities (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL
);

-- Many-to-many link between rooms and facilities.
CREATE TABLE IF NOT EXISTS public.room_facilities (
  room_id bigint NOT NULL REFERENCES public.rooms (id),
  facility_id bigint NOT NULL REFERENCES public.facilities (id),
  PRIMARY KEY (room_id, facility_id)
);

-- Recurring weekly timetable entries for a branch-year.
CREATE TABLE IF NOT EXISTS public.timetable (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  branch_id bigint NOT NULL REFERENCES public.branches (id),
  year_id bigint NOT NULL REFERENCES public.academic_years (id),
  subject_name text NOT NULL,
  faculty_id uuid NOT NULL REFERENCES public.profiles (id),
  room_id bigint NOT NULL REFERENCES public.rooms (id),
  weekday smallint NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  valid_from date NOT NULL,
  valid_until date,
  status text NOT NULL DEFAULT 'scheduled'
);

-- Date-specific cancellations or room moves for a timetable entry.
CREATE TABLE IF NOT EXISTS public.timetable_exceptions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  timetable_id bigint NOT NULL REFERENCES public.timetable (id),
  exception_date date NOT NULL,
  type text NOT NULL,
  new_room_id bigint REFERENCES public.rooms (id),
  reason text NOT NULL,
  created_by uuid NOT NULL REFERENCES public.profiles (id)
);

-- Classroom booking requests and reservations.
CREATE TABLE IF NOT EXISTS public.bookings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room_id bigint NOT NULL REFERENCES public.rooms (id),
  user_id uuid NOT NULL REFERENCES public.profiles (id),
  booking_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  expected_occupants integer NOT NULL,
  purpose text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Periods when a room cannot be allocated (e.g. maintenance).
CREATE TABLE IF NOT EXISTS public.room_restrictions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room_id bigint NOT NULL REFERENCES public.rooms (id),
  start_datetime timestamptz NOT NULL,
  end_datetime timestamptz NOT NULL,
  reason text
);

-- Audit log of actions taken on bookings.
CREATE TABLE IF NOT EXISTS public.booking_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_id bigint NOT NULL REFERENCES public.bookings (id),
  action text NOT NULL,
  performed_by uuid NOT NULL REFERENCES public.profiles (id),
  timestamp timestamptz NOT NULL DEFAULT now()
);

-- Row level security; policies will be added in the login and roles step.
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetable ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetable_exceptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_restrictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_history ENABLE ROW LEVEL SECURITY;
