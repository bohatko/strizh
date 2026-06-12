CREATE OR REPLACE FUNCTION public.generate_master_time_slots(
  months_ahead integer DEFAULT 2
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inserted_count integer := 0;
  slot_hours integer[] := ARRAY[7, 8, 9, 11, 12, 13, 15, 16];
  master_row record;
  day_row date;
  slot_hour integer;
  slot_start timestamptz;
  slot_end timestamptz;
  last_day date;
BEGIN
  last_day := (CURRENT_DATE + make_interval(months => months_ahead))::date;

  FOR master_row IN SELECT id FROM public.masters ORDER BY id LOOP
    FOR day_row IN
      SELECT generate_series(CURRENT_DATE, last_day, interval '1 day')::date
    LOOP
      FOREACH slot_hour IN ARRAY slot_hours LOOP
        slot_start := make_timestamptz(
          EXTRACT(YEAR FROM day_row)::integer,
          EXTRACT(MONTH FROM day_row)::integer,
          EXTRACT(DAY FROM day_row)::integer,
          slot_hour,
          0,
          0,
          'UTC'
        );
        slot_end := slot_start + interval '1 hour';

        IF NOT EXISTS (
          SELECT 1
          FROM public.time_slots ts
          WHERE ts.master_id = master_row.id
            AND ts.start_time = slot_start
        ) THEN
          INSERT INTO public.time_slots (
            master_id,
            start_time,
            end_time,
            is_booked
          )
          VALUES (
            master_row.id,
            slot_start,
            slot_end,
            false
          );

          inserted_count := inserted_count + 1;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RETURN inserted_count;
END;
$$;

SELECT public.generate_master_time_slots(2);
