-- Part 3.6: constraint tests. Every test is rolled back; no data is saved.
DROP TABLE IF EXISTS pg_temp.test_results;
CREATE TEMP TABLE test_results (
  id int GENERATED ALWAYS AS IDENTITY,
  test text, expected_code text, got_code text,
  expected_constraint text, got_constraint text, result text
);

DO $do$
DECLARE
  t record;
  got_code text;
  got_con text;
BEGIN
  FOR t IN
    SELECT * FROM (VALUES

    -- rooms
    ('rooms: capacity 0 rejected', '23514', 'rooms_capacity_check',
     $q$INSERT INTO public.rooms (room_number,building,floor,capacity,room_type) VALUES ('T-1','TEST',1,0,'lecture_hall')$q$),
    ('rooms: bad status rejected', '23514', 'rooms_status_check',
     $q$INSERT INTO public.rooms (room_number,building,floor,capacity,room_type,status) VALUES ('T-2','TEST',1,30,'lecture_hall','broken')$q$),
    ('rooms: bad room type rejected', '23514', 'rooms_room_type_check',
     $q$INSERT INTO public.rooms (room_number,building,floor,capacity,room_type) VALUES ('T-3','TEST',1,30,'garage')$q$),
    ('rooms: duplicate building+number rejected', '23505', 'rooms_building_room_number_key',
     $q$INSERT INTO public.rooms (room_number,building,floor,capacity,room_type) VALUES ('S-101','SAMPLE',1,30,'lecture_hall')$q$),

    -- academic years and profiles
    ('academic_years: year 5 rejected', '23514', 'academic_years_year_number_check',
     $q$INSERT INTO public.academic_years (year_number,name,code) VALUES (5,'Fifth Year','XY')$q$),
    ('profiles: bad role rejected', '23514', 'profiles_role_check',
     $q$INSERT INTO public.profiles (id,name,email,role) VALUES (gen_random_uuid(),'X','x@example.com','principal')$q$),

    -- timetable
    ('timetable: end before start rejected', '23514', 'timetable_end_after_start_check',
     $q$INSERT INTO public.timetable (branch_id,year_id,subject_name,faculty_id,room_id,weekday,start_time,end_time,valid_from)
        SELECT b.id,y.id,'T',p.id,r.id,1,TIME '11:00',TIME '10:00',DATE '2026-11-01'
        FROM public.branches b, public.academic_years y, public.profiles p, public.rooms r
        WHERE b.code='IT' AND y.year_number=2 AND p.email='faculty.test@example.com'
          AND r.building='SAMPLE' AND r.room_number='S-101'$q$),
    ('timetable: weekday 8 rejected', '23514', 'timetable_weekday_check',
     $q$INSERT INTO public.timetable (branch_id,year_id,subject_name,faculty_id,room_id,weekday,start_time,end_time,valid_from)
        SELECT b.id,y.id,'T',p.id,r.id,8,TIME '10:00',TIME '11:00',DATE '2026-11-01'
        FROM public.branches b, public.academic_years y, public.profiles p, public.rooms r
        WHERE b.code='IT' AND y.year_number=2 AND p.email='faculty.test@example.com'
          AND r.building='SAMPLE' AND r.room_number='S-101'$q$),
    ('timetable: valid_until before valid_from rejected', '23514', 'timetable_valid_range_check',
     $q$INSERT INTO public.timetable (branch_id,year_id,subject_name,faculty_id,room_id,weekday,start_time,end_time,valid_from,valid_until)
        SELECT b.id,y.id,'T',p.id,r.id,1,TIME '10:00',TIME '11:00',DATE '2026-11-10',DATE '2026-11-01'
        FROM public.branches b, public.academic_years y, public.profiles p, public.rooms r
        WHERE b.code='IT' AND y.year_number=2 AND p.email='faculty.test@example.com'
          AND r.building='SAMPLE' AND r.room_number='S-101'$q$),

    -- timetable_exceptions
    ('exceptions: moved without new room rejected', '23514', 'timetable_exceptions_new_room_id_check',
     $q$INSERT INTO public.timetable_exceptions (timetable_id,exception_date,type,new_room_id,reason,created_by)
        SELECT t.id,DATE '2026-12-01','moved',NULL::bigint,'t',p.id
        FROM public.timetable t, public.profiles p
        WHERE t.subject_name='[SAMPLE] Data Structures' AND p.email='admin.test@example.com'$q$),
    ('exceptions: cancelled with new room rejected', '23514', 'timetable_exceptions_new_room_id_check',
     $q$INSERT INTO public.timetable_exceptions (timetable_id,exception_date,type,new_room_id,reason,created_by)
        SELECT t.id,DATE '2026-12-01','cancelled',r.id,'t',p.id
        FROM public.timetable t, public.rooms r, public.profiles p
        WHERE t.subject_name='[SAMPLE] Data Structures' AND r.building='SAMPLE' AND r.room_number='S-201'
          AND p.email='admin.test@example.com'$q$),
    ('exceptions: second exception on same date rejected', '23505', 'timetable_exceptions_timetable_id_exception_date_key',
     $q$INSERT INTO public.timetable_exceptions (timetable_id,exception_date,type,new_room_id,reason,created_by)
        SELECT timetable_id,exception_date,'cancelled',NULL::bigint,'dup',created_by
        FROM public.timetable_exceptions LIMIT 1$q$),

    -- room_restrictions
    ('restrictions: end before start rejected', '23514', 'room_restrictions_end_after_start_check',
     $q$INSERT INTO public.room_restrictions (room_id,start_datetime,end_datetime,reason)
        SELECT id,TIMESTAMPTZ '2026-12-02 10:00+05:30',TIMESTAMPTZ '2026-12-02 09:00+05:30','t'
        FROM public.rooms WHERE building='SAMPLE' AND room_number='S-201'$q$),

    -- bookings: invalid values (all should be rejected)
    ('bookings: end before start rejected', '23514', 'bookings_end_after_start_check',
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-10',TIME '15:00',TIME '14:00',5,'t','pending'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-202' AND p.email='student.test@example.com'$q$),
    ('bookings: 0 occupants rejected', '23514', 'bookings_expected_occupants_check',
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-10',TIME '15:00',TIME '16:00',0,'t','pending'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-202' AND p.email='student.test@example.com'$q$),
    ('bookings: bad status rejected', '23514', 'bookings_status_check',
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-10',TIME '15:00',TIME '16:00',5,'t','approved'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-202' AND p.email='student.test@example.com'$q$),
    ('bookings: starts before 8:00 rejected', '23514', 'bookings_hours_check',
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-10',TIME '07:00',TIME '08:00',5,'t','pending'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-202' AND p.email='student.test@example.com'$q$),
    ('bookings: ends after 18:00 rejected', '23514', 'bookings_hours_check',
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-10',TIME '17:30',TIME '18:30',5,'t','pending'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-202' AND p.email='student.test@example.com'$q$),
    ('bookings: 10:10 start rejected (30-min steps)', '23514', 'bookings_time_steps_check',
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-10',TIME '10:10',TIME '11:00',5,'t','pending'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-202' AND p.email='student.test@example.com'$q$),

    -- bookings: the overlap rule
    ('bookings: overlapping CONFIRMED rejected', '23P01', 'bookings_confirmed_no_overlap',
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-03',TIME '13:30',TIME '14:30',10,'t','confirmed'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-201' AND p.email='student.test@example.com'$q$),
    ('bookings: back-to-back CONFIRMED allowed', 'ACCEPTED', NULL,
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-03',TIME '15:00',TIME '16:00',10,'t','confirmed'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-201' AND p.email='student.test@example.com'$q$),
    ('bookings: overlapping PENDING allowed', 'ACCEPTED', NULL,
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-03',TIME '13:30',TIME '14:30',10,'t','pending'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-201' AND p.email='student.test@example.com'$q$),
    ('bookings: same time, different room allowed', 'ACCEPTED', NULL,
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-03',TIME '13:00',TIME '14:00',10,'t','confirmed'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-202' AND p.email='student.test@example.com'$q$),
    ('bookings: same room and time, different date allowed', 'ACCEPTED', NULL,
     $q$INSERT INTO public.bookings (room_id,user_id,booking_date,start_time,end_time,expected_occupants,purpose,status)
        SELECT r.id,p.id,DATE '2026-11-04',TIME '13:00',TIME '14:00',10,'t','confirmed'
        FROM public.rooms r, public.profiles p
        WHERE r.building='SAMPLE' AND r.room_number='S-201' AND p.email='student.test@example.com'$q$)

    ) AS v(test, expected_code, expected_constraint, stmt)
  LOOP
    got_code := 'ACCEPTED';
    got_con := NULL;
    BEGIN
      EXECUTE t.stmt;
      RAISE EXCEPTION 'undo test' USING ERRCODE = 'ZZ001';  -- rolls the insert back
    EXCEPTION WHEN OTHERS THEN
      IF SQLSTATE <> 'ZZ001' THEN
        got_code := SQLSTATE;
        GET STACKED DIAGNOSTICS got_con = CONSTRAINT_NAME;
      END IF;
    END;

    INSERT INTO pg_temp.test_results
      (test, expected_code, got_code, expected_constraint, got_constraint, result)
    VALUES (t.test, t.expected_code, got_code, t.expected_constraint, got_con,
      CASE WHEN got_code = t.expected_code
                AND got_con IS NOT DISTINCT FROM t.expected_constraint
           THEN 'PASS' ELSE 'FAIL' END);
  END LOOP;
END
$do$;

SELECT id, test, result, expected_code, got_code, expected_constraint, got_constraint
FROM pg_temp.test_results ORDER BY id;