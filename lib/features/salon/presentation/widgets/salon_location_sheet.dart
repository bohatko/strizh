import 'package:flutter/material.dart';
import 'package:app_template/theme.dart';
import 'package:url_launcher/url_launcher.dart';

const _salonName = 'Стриж Beauty Studio';
const _salonAddress = 'Молодёжный проспект, 31к2, Нижний Новгород';
const _salonHours = 'Ежедневно с 10 до 7';
const _salonPhone = '+7 (831) 259-71-70';
const _salonMetro = 'ст. метро Парк культуры, 10 мин';
const _yandexMapsUrl =
    'https://yandex.ru/maps/org/strizh/1059589301?si=15bwv89rj7rvnxb8w75wb7z2bg';
const _mapLongitude = 43.8462;
const _mapLatitude = 56.2417;

Future<void> _openYandexMaps() async {
  final uri = Uri.parse(_yandexMapsUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> showSalonLocationSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) => const _SalonLocationSheetBody(),
  );
}

class _SalonLocationSheetBody extends StatelessWidget {
  const _SalonLocationSheetBody();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Локация салона', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _salonName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _salonAddress,
            style: Theme.of(context).textTheme.bodyMedium?.withColor(
              cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openYandexMaps,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    'https://static-maps.yandex.ru/1.x/?lang=ru_RU&ll=$_mapLongitude,$_mapLatitude&size=650,360&z=16&l=map&pt=$_mapLongitude,$_mapLatitude,pm2rdm',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      child: Center(
                        child: Text(
                          'Не удалось загрузить карту',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.withColor(cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.schedule,
                  text: _salonHours,
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  icon: Icons.phone,
                  text: _salonPhone,
                  onTap: () => launchUrl(Uri.parse('tel:+78312597170')),
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  icon: Icons.directions_walk,
                  text: _salonMetro,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.withColor(
              cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: child,
    );
  }
}
