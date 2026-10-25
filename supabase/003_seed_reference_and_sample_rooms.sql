-- Part 3.5a: reference data (keep) and sample rooms (delete later).

-- REAL reference data: branches
INSERT INTO public.branches (name, code) VALUES
  ('Information Technology', 'IT'),
  ('Computer Science and Engineering', 'CSE'),
  ('Civil Engineering', 'CE'),
  ('Artificial Intelligence and Machine Learning', 'AIM')
ON CONFLICT (code) DO NOTHING;

-- REAL reference data: academic years
INSERT INTO public.academic_years (year_number, name, code) VALUES
  (1, 'First Year', 'FY'),
  (2, 'Second Year', 'SY'),
  (3, 'Third Year', 'TY'),
  (4, 'Fourth Year', 'LY')
ON CONFLICT (year_number) DO NOTHING;

-- REAL reference data: common facilities (edit later to match your college)
INSERT INTO public.facilities (name)
SELECT v.name
FROM (VALUES
  ('Projector'), ('Smart Board'), ('Computers'),
  ('Air Conditioning'), ('Audio System')
) AS v(name)
WHERE NOT EXISTS (
  SELECT 1 FROM public.facilities f WHERE f.name = v.name
);

-- SAMPLE rooms: all in building 'SAMPLE' so they are easy to find and delete.
INSERT INTO public.rooms (room_number, building, floor, capacity, room_type, status) VALUES
  ('S-101', 'SAMPLE', 1, 60,  'lecture_hall', 'active'),
  ('S-102', 'SAMPLE', 1, 120, 'lecture_hall', 'active'),
  ('S-201', 'SAMPLE', 2, 30,  'seminar_room', 'active'),
  ('S-202', 'SAMPLE', 2, 40,  'laboratory',   'active'),
  ('S-301', 'SAMPLE', 3, 60,  'lecture_hall', 'maintenance')
ON CONFLICT (building, room_number) DO NOTHING;

-- SAMPLE room facilities
INSERT INTO public.room_facilities (room_id, facility_id)
SELECT r.id, f.id
FROM public.rooms r
JOIN public.facilities f ON (r.room_number, f.name) IN (
  ('S-101', 'Projector'),
  ('S-102', 'Projector'),
  ('S-102', 'Audio System'),
  ('S-201', 'Smart Board'),
  ('S-202', 'Computers'),
  ('S-202', 'Projector')
)
WHERE r.building = 'SAMPLE'
ON CONFLICT DO NOTHING;