import 'package:flutter/material.dart';

class _FailedImageUrls {
  static final Set<String> _urls = <String>{};

  static bool contains(String url) => _urls.contains(url);

  static void add(String url) => _urls.add(url);
}

class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.fallback,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty || _FailedImageUrls.contains(normalized)) {
      return fallback ?? const SizedBox.shrink();
    }

    return Image.network(
      normalized,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        _FailedImageUrls.add(normalized);
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

class SafeNetworkAvatar extends StatelessWidget {
  const SafeNetworkAvatar({
    super.key,
    required this.url,
    required this.radius,
    this.backgroundColor,
    this.icon = Icons.person_outline,
    this.iconSize,
    this.iconColor,
  });

  final String? url;
  final double radius;
  final Color? backgroundColor;
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final colorScheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colorScheme.surfaceContainerHighest;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: iconSize ?? radius,
        color: iconColor ?? colorScheme.onSurfaceVariant,
      ),
    );

    return ClipOval(
      child: SafeNetworkImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}
