# Booking screen (`/booking`)

## Calendar month navigation

The visible calendar month changes only when:

- slots are first loaded;
- the selected date changes (including auto-selection after master change);
- the user taps the previous/next month arrows.

It is no longer reset on every rebuild, so month arrows work while a date stays selected.

## Time slots loading

Available slots are loaded from `time_slots` with `is_booked = false` and `start_time >= now`, up to **2000** rows per master (about six months of schedule windows).

## Related files

- `lib/features/booking/presentation/pages/booking_page.dart`
