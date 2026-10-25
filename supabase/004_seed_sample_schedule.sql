-- Part 3.5b: SAMPLE schedule data. Delete before loading real college data.
-- Weekday numbering: 1 = Monday ... 7 = Sunday. Run this script ONCE.

-- SAMPLE weekly timetable (all taught by the test faculty user)
INSERT INTO public.timetable
  (branch_id, year_id, subject_name, faculty_id, room_id,
   weekday, start_time, end_time, valid_from, valid_until, status)
SELECT b.id, y.id, v.subject, p.id, r.id,
       v.weekday, v.start_time::time, v.end_time::time,
       v.valid_from::date, v.valid_until::date, 'scheduled'
FROM (VALUES
  ('IT',  2, '[SAMPLE] Data Structures',     'S-101', 1, '10:00', '11:00', '2026-10-26', '2026-12-18'),
  ('IT',  2, '[SAMPLE] Database Systems',    'S-101', 1, '14:30', '15:30', '2026-10-26', '2026-12-18'),
  ('CSE', 3, '[SAMPLE] Operating Systems Lab','S-202', 2, '11:00', '13:00', '2026-10-26', '2026-12-18'),
  ('CE',  1, '[SAMPLE] Engineering Mechanics','S-102', 3, '09:00', '10:00', '2026-10-26', '2026-12-18'),
  ('IT',  2, '[SAMPLE] Software Engineering','S-201', 5, '10:00', '11:00', '2026-10-26', '2026-12-18')
) AS v(branch_code, year_number, subject, room_number, weekday,
       start_time, end_time, valid_from, valid_until)
JOIN public.branches b        ON b.code = v.branch_code
JOIN public.academic_years y  ON y.year_number = v.year_number
JOIN public.rooms r           ON r.building = 'SAMPLE' AND r.room_number = v.room_number
CROSS JOIN (SELECT id FROM public.profiles
            WHERE email = 'faculty.test@example.com') p;

-- SAMPLE exception 1: Monday 9 Nov Data Structures is cancelled
INSERT INTO public.timetable_exceptions
  (timetable_id, exception_date, type, new_room_id, reason, created_by)
SELECT t.id, '2026-11-09'::date, 'cancelled', NULL,
       '[SAMPLE] Faculty on leave', a.id
FROM public.timetable t
CROSS JOIN (SELECT id FROM public.profiles
            WHERE email = 'admin.test@example.com') a
WHERE t.subject_name = '[SAMPLE] Data Structures';

-- SAMPLE exception 2: Friday 6 Nov Software Engineering moves to S-101
INSERT INTO public.timetable_exceptions
  (timetable_id, exception_date, type, new_room_id, reason, created_by)
SELECT t.id, '2026-11-06'::date, 'moved', r.id,
       '[SAMPLE] Room swap', a.id
FROM public.timetable t
JOIN public.rooms r ON r.building = 'SAMPLE' AND r.room_number = 'S-101'
CROSS JOIN (SELECT id FROM public.profiles
            WHERE email = 'admin.test@example.com') a
WHERE t.subject_name = '[SAMPLE] Software Engineering';

-- SAMPLE restriction: S-102 closed 16-20 Nov (projector repair)
INSERT INTO public.room_restrictions (room_id, start_datetime, end_datetime, reason)
SELECT r.id,
       '2026-11-16 00:00:00+05:30'::timestamptz,
       '2026-11-20 23:59:00+05:30'::timestamptz,
       '[SAMPLE] Projector repair'
FROM public.rooms r
WHERE r.building = 'SAMPLE' AND r.room_number = 'S-102';

-- SAMPLE bookings
INSERT INTO public.bookings
  (room_id, user_id, booking_date, start_time, end_time,
   expected_occupants, purpose, status)
SELECT r.id, p.id, v.booking_date::date, v.start_time::time, v.end_time::time,
       v.occupants, v.purpose, v.status
FROM (VALUES
  ('S-201', 'faculty.test@example.com', '2026-11-03', '13:00', '14:00', 25, '[SAMPLE] Guest lecture',                   'confirmed'),
  ('S-201', 'admin.test@example.com',   '2026-11-03', '14:00', '15:00', 20, '[SAMPLE] Project review (back-to-back)',   'confirmed'),
  ('S-202', 'student.test@example.com', '2026-11-04', '15:00', '16:00',  8, '[SAMPLE] Group project work',             'pending'),
  ('S-201', 'student.test@example.com', '2026-11-03', '13:00', '14:00', 10, '[SAMPLE] Cancelled study session',         'cancelled')
) AS v(room_number, email, booking_date, start_time, end_time,
       occupants, purpose, status)
JOIN public.rooms r    ON r.building = 'SAMPLE' AND r.room_number = v.room_number
JOIN public.profiles p ON p.email = v.email;