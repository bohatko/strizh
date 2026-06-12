# Time slots (`time_slots`)

## Schedule pattern

Each master gets 1-hour slots at UTC hours `7, 8, 9, 11, 12, 13, 15, 16` for every calendar day (salon working hours with a lunch break).

## Generating slots

Function: `public.generate_master_time_slots(months_ahead integer DEFAULT 2)`

- Starts from `CURRENT_DATE`
- Ends `months_ahead` months later
- Inserts only missing `(master_id, start_time)` pairs
- Returns the number of inserted rows

Run in Supabase SQL editor (`months_ahead` is counted from `CURRENT_DATE`; existing slots are skipped):

```sql
SELECT public.generate_master_time_slots(6);
```

Example schedule after extension: about **6 months** ahead from today for every master, 8 slots per day.

Migration: `supabase/migrations/20260612130000_generate_master_time_slots.sql`

## Booking lifecycle

- **Book:** `booking_page.dart` sets `is_booked = true` and `appointment_id` on the chosen slot.
- **Cancel / archive:** `SupabaseService.releaseTimeSlotsForAppointment()` clears `is_booked` and `appointment_id` (used from client cancellations and admin status changes).

## Related files

- `lib/features/booking/presentation/pages/booking_page.dart`
- `lib/features/booking/presentation/pages/my_appointments_page.dart`
- `lib/supabase/supabase_config.dart`
