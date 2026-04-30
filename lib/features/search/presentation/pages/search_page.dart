import 'package:flutter/material.dart';
import 'package:app_template/theme.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Search screen placeholder',
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
