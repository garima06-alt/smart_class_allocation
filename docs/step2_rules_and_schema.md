# Step 2 - Rules and Database Design

## Section 1: Rules

- Overlap check: ExistingStart < RequestedEnd AND ExistingEnd > RequestedStart
- Back-to-back sessions are allowed (no buffer for now; a buffer setting may be added later)
- A room is blocked by: scheduled timetable lectures (after exceptions), confirmed bookings, and room restrictions. Pending bookings do not block a room, but availability is rechecked at approval time.
- Booking hours: 8:00 AM to 6:00 PM in 30-minute steps
- Years stored as numbers 1 to 4: First Year (FY), Second Year (SY), Third Year (TY), Fourth Year (LY)
- Roles: admin, faculty, student
- Admin bookings: confirmed automatically after validation
- Faculty bookings: confirmed automatically after validation
- Student bookings: start as pending; approved or rejected by an admin or by a faculty member whose profile has can_approve = true
- Booking statuses: pending, confirmed, rejected, cancelled
- Timetable entry statuses: scheduled, inactive
- Room statuses: active, maintenance, closed
- Room types: lecture_hall, laboratory, seminar_room, other
- Ranking: smallest room that fits the expected occupants wins; ties go to preferred building or floor
- Rooms are not hard-coded: the real rooms and labs will be added later by an admin.
- Effective schedule for a requested date = weekly timetable entries for that weekday within valid_from/valid_until, minus entries cancelled by an exception on that date, with moved entries using their new room. One-off extra sessions are stored as admin bookings.

## Section 2: Tables

1. **branches:** id, name, code (IT, CSE, CE, AIM)
2. **academic_years:** id, year_number (1-4), name, code
3. **profiles:** id (same as Supabase auth user id), name, email, role, branch_id, can_approve (boolean, default false)
4. **rooms:** id, room_number, building, floor, capacity, room_type, status
5. **facilities:** id, name
6. **room_facilities:** room_id -> rooms, facility_id -> facilities
7. **timetable:** id, branch_id, year_id, subject_name, faculty_id -> profiles, room_id -> rooms, weekday (1-7), start_time, end_time, valid_from, valid_until, status
8. **timetable_exceptions:** id, timetable_id -> timetable, exception_date, type (cancelled or moved), new_room_id -> rooms (only for moved), reason, created_by
9. **bookings:** id, room_id, user_id, booking_date, start_time, end_time, expected_occupants, purpose, status, created_at
10. **room_restrictions:** id, room_id, start_datetime, end_datetime, reason
11. **booking_history:** id, booking_id, action, performed_by, timestamp

## Section 3: Rules the database must enforce later (Step 3)

- end_time > start_time wherever times exist
- capacity > 0
- Two confirmed bookings for the same room cannot overlap (PostgreSQL exclusion constraint)
- A moved exception must have new_room_id; a cancelled exception must not

## Section 4: Relationships

- A room has many facilities; a facility belongs to many rooms
- A timetable entry belongs to one branch, one year, one room and one faculty member
- An exception belongs to one timetable entry and affects one date
- A booking belongs to one room and one user

## Section 5: Design check scenarios (each must be answerable from the tables)

1. Weekly Monday 10:00-11:00 lecture in a room is found on any Monday within its valid range.
2. If cancelled on one date, the room is free on that date only.
3. If moved to another room on one date, the original room is free and the new room is busy on that date.
4. A room under maintenance is blocked by room_restrictions, not by the timetable.
5. A student request is saved as pending and does not block other users.

## Section 6: Decisions made while building the database (Step 3)

Database files, run in this order in the Supabase SQL Editor:
- supabase/001_create_tables.sql (11 tables, row level security enabled)
- supabase/002_add_constraints.sql (integrity rules)
- supabase/003_seed_reference_and_sample_rooms.sql
- supabase/004_seed_sample_schedule.sql
- supabase/005_test_constraints.sql (tests; rolls back, saves nothing)

Schema decisions:
- timetable_exceptions.reason is required (an admin must give a reason)
- timetable.faculty_id is required
- profiles.branch_id may be empty (admins have no branch)
- Pending, rejected and cancelled bookings never block a room; only confirmed bookings do
- The database blocks overlapping confirmed bookings in the same room on the same date. Time ranges are half-open [start, end), so back-to-back bookings are allowed
- The database does NOT compare bookings with timetable lectures or room restrictions. That cross-check belongs to the availability engine (Step 4)
- Time zone for room_restrictions: Asia/Kolkata (+05:30)

Extra constraints beyond the original list:
- Unique: (building, room_number), branch code, year_number, and one exception per timetable entry per date
- Booking times must be between 08:00 and 18:00, in 30-minute steps

Sample data rules (delete before loading real college data):
- Sample rooms use building = 'SAMPLE'
- Sample timetable, exception, restriction and booking text starts with '[SAMPLE]'
- Test users: admin.test@example.com, faculty.test@example.com, student.test@example.com (no passwords stored in the project)
- Real reference data to keep: branches, academic_years, facilities

Availability logic location (decided at Step 4): to be recorded here.
