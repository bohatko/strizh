import 'package:flutter/material.dart';
import 'package:app_template/theme.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Shop screen placeholder',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.withColor(cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
