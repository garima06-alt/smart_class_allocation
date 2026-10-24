-- Part 3.4: integrity rules for the existing empty tables.

-- profiles: allowed roles.
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'faculty', 'student'));

-- rooms: capacity, status, type, and unique building + room number.
ALTER TABLE public.rooms
  ADD CONSTRAINT rooms_capacity_check
  CHECK (capacity > 0);

ALTER TABLE public.rooms
  ADD CONSTRAINT rooms_status_check
  CHECK (status IN ('active', 'maintenance', 'closed'));

ALTER TABLE public.rooms
  ADD CONSTRAINT rooms_room_type_check
  CHECK (room_type IN ('lecture_hall', 'laboratory', 'seminar_room', 'other'));

ALTER TABLE public.rooms
  ADD CONSTRAINT rooms_building_room_number_key
  UNIQUE (building, room_number);

-- branches: unique code.
ALTER TABLE public.branches
  ADD CONSTRAINT branches_code_key
  UNIQUE (code);

-- academic_years: unique year_number in 1-4.
ALTER TABLE public.academic_years
  ADD CONSTRAINT academic_years_year_number_key
  UNIQUE (year_number);

ALTER TABLE public.academic_years
  ADD CONSTRAINT academic_years_year_number_check
  CHECK (year_number BETWEEN 1 AND 4);

-- timetable: times, weekday, status, and valid date range.
ALTER TABLE public.timetable
  ADD CONSTRAINT timetable_end_after_start_check
  CHECK (end_time > start_time);

ALTER TABLE public.timetable
  ADD CONSTRAINT timetable_weekday_check
  CHECK (weekday BETWEEN 1 AND 7);

ALTER TABLE public.timetable
  ADD CONSTRAINT timetable_status_check
  CHECK (status IN ('scheduled', 'inactive'));

ALTER TABLE public.timetable
  ADD CONSTRAINT timetable_valid_range_check
  CHECK (valid_until IS NULL OR valid_until >= valid_from);

-- timetable_exceptions: type, moved/cancelled room rule, one exception per entry per date.
ALTER TABLE public.timetable_exceptions
  ADD CONSTRAINT timetable_exceptions_type_check
  CHECK (type IN ('cancelled', 'moved'));

ALTER TABLE public.timetable_exceptions
  ADD CONSTRAINT timetable_exceptions_new_room_id_check
  CHECK (
    (type = 'moved' AND new_room_id IS NOT NULL)
    OR (type = 'cancelled' AND new_room_id IS NULL)
  );

ALTER TABLE public.timetable_exceptions
  ADD CONSTRAINT timetable_exceptions_timetable_id_exception_date_key
  UNIQUE (timetable_id, exception_date);

-- room_restrictions: end after start.
ALTER TABLE public.room_restrictions
  ADD CONSTRAINT room_restrictions_end_after_start_check
  CHECK (end_datetime > start_datetime);

-- bookings: times, occupants, status, hours, and 30-minute steps.
ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_end_after_start_check
  CHECK (end_time > start_time);

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_expected_occupants_check
  CHECK (expected_occupants > 0);

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending', 'confirmed', 'rejected', 'cancelled'));

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_hours_check
  CHECK (start_time >= TIME '08:00' AND end_time <= TIME '18:00');

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_time_steps_check
  CHECK (
    EXTRACT(MINUTE FROM start_time) IN (0, 30)
    AND EXTRACT(SECOND FROM start_time) = 0
    AND EXTRACT(MINUTE FROM end_time) IN (0, 30)
    AND EXTRACT(SECOND FROM end_time) = 0
  );

-- Confirmed bookings for the same room cannot overlap; back-to-back is allowed.
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_confirmed_no_overlap
  EXCLUDE USING gist (
    room_id WITH =,
    tsrange(
      (booking_date + start_time),
      (booking_date + end_time),
      '[)'
    ) WITH &&
  )
  WHERE (status = 'confirmed');
