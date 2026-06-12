# Masters

## Portfolio / work examples

Work photos are stored in `masters.works_images` (`text[]`).

The master profile screen (`/masters/:masterId`) reads this array and shows a horizontal gallery under **Примеры работ**.

Admins manage URLs in the admin panel master form: paste a link or upload from gallery into the `masters` Storage bucket (gallery permission is requested before the picker). See `docs/admin.md` and `lib/core/permissions/gallery_permission.dart`.

## Related files

- `lib/features/masters/presentation/pages/master_details_page.dart`
- `lib/features/admin/presentation/pages/admin_panel_page.dart`
