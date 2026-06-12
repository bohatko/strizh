# Home screen (`/home`)

## Overview

The home screen shows a promo carousel, popular services, and masters loaded from Supabase.

## Data loading

Services and masters are fetched once in `initState` and stored in:

- `_popularServicesFuture` — services with aggregated review ratings
- `_mastersFuture` — master list

`FutureBuilder` widgets reuse these cached futures so scrolling the promo carousel does not trigger new database requests.

## Promo carousel

The promo `PageView` lives in `_PromoCarousel`, a separate `StatefulWidget`. Page indicator updates call `setState` only inside that widget, so the rest of the home screen (including loaded lists) is not rebuilt on swipe.

## Salon location

The **Локация салона** tile opens a bottom sheet with address, map, hours, phone, and metro info. See `docs/salon.md`.

## Related files

- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/salon/presentation/widgets/salon_location_sheet.dart`
