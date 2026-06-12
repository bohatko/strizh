# Appointments (`appointments`)

## Status values

| Status | Label (RU) |
|--------|------------|
| `pending` | Ожидает |
| `confirmed` | Подтверждено |
| `completed` | Завершено |
| `cancelled` | Отменено |
| `archived` | Архив |

The `status` column in `public.appointments` is constrained by `appointments_status_check` and accepts only the values listed above.

Migration: `supabase/migrations/20260612120000_add_archived_appointment_status.sql`

## Admin panel — tab «Заказы»

- Each order card has a **Статус** dropdown with all values above, including **Архив**.
- Selecting **Архив** updates `appointments.status` to `archived` in Supabase.
- A horizontal chip filter above the list narrows orders by status: `Все`, `Ожидает`, `Подтверждено`, `Завершено`, `Отменено`, `Архив`.
- The client line shows the profile display name (`display_name`, or `first_name` + `last_name`). If none is set, the label **клиент** is used instead of the raw `client_id`.

## Related files

- `lib/features/admin/presentation/pages/admin_panel_page.dart`
- `lib/features/booking/presentation/pages/my_appointments_page.dart`
