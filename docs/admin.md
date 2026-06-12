# Admin panel (`/admin`)

## Master form

The master create/edit form opens as a modal bottom sheet with `32px` top padding.

### User account dropdown

- **Create:** admins can pick a free profile. The list excludes profiles with role `user` and accounts already linked to another master.
- **Edit:** the user account field is hidden; the existing `user_id` is kept on save.

## Service price and booking

Booking reads the price from `master_services.price` (link between master and service), not only from `services.price`.

When a service is saved in the admin panel, `price` and `duration` are propagated to all existing `master_services` rows for that service. The same sync runs when master–service links are updated from the master form.

## Related files

- `lib/features/admin/presentation/pages/admin_panel_page.dart`
