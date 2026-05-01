import 'package:app_template/core/ui/admin_access_icon.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminPanelPage extends ConsumerStatefulWidget {
  const AdminPanelPage({super.key});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final auth = ref.read(authControllerProvider).asData?.value;
    return auth is Authenticated && auth.user.role?.toLowerCase() == 'admin';
  }

  Future<List<Map<String, dynamic>>> _loadMasters() async {
    return SupabaseService.select(
      'masters',
      select: 'id, specialty, level, bio, avatar_url, created_at',
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<List<Map<String, dynamic>>> _loadServices() async {
    return SupabaseService.select(
      'services',
      select: 'id, name, category, description, duration, price, image_url, created_at',
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _deleteMaster(int id) async {
    final shouldDelete = await _confirmDelete(
      title: 'Удалить мастера?',
      message:
          'Мастер будет удалён из базы. Если есть связанные записи, база может отклонить удаление.',
    );
    if (!shouldDelete) return;
    await _runGuarded(() async {
      await SupabaseService.delete('masters', filters: {'id': id});
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Мастер удалён');
    });
  }

  Future<void> _deleteService(int id) async {
    final shouldDelete = await _confirmDelete(
      title: 'Удалить услугу?',
      message:
          'Услуга будет удалена. Если есть связанные записи, база может отклонить удаление.',
    );
    if (!shouldDelete) return;
    await _runGuarded(() async {
      await SupabaseService.delete('services', filters: {'id': id});
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Услуга удалена');
    });
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _openMasterForm({Map<String, dynamic>? initial}) async {
    final specialtyCtrl = TextEditingController(
      text: (initial?['specialty'] ?? '').toString(),
    );
    final levelCtrl = TextEditingController(
      text: (initial?['level'] ?? '').toString(),
    );
    final bioCtrl = TextEditingController(
      text: (initial?['bio'] ?? '').toString(),
    );
    final avatarCtrl = TextEditingController(
      text: (initial?['avatar_url'] ?? '').toString(),
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  initial == null ? 'Новый мастер' : 'Редактирование мастера',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: specialtyCtrl,
                  decoration: const InputDecoration(labelText: 'Специализация *'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: levelCtrl,
                  decoration: const InputDecoration(labelText: 'Уровень'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: bioCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: avatarCtrl,
                  decoration: const InputDecoration(labelText: 'URL аватара'),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    if (specialtyCtrl.text.trim().isEmpty) {
                      AppSnackbar.showError(
                        sheetContext,
                        'Поле "Специализация" обязательно',
                      );
                      return;
                    }
                    Navigator.of(sheetContext).pop(true);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(initial == null ? 'Создать' : 'Сохранить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != true) {
      specialtyCtrl.dispose();
      levelCtrl.dispose();
      bioCtrl.dispose();
      avatarCtrl.dispose();
      return;
    }

    final payload = <String, dynamic>{
      'specialty': specialtyCtrl.text.trim(),
      'level': levelCtrl.text.trim().isEmpty ? null : levelCtrl.text.trim(),
      'bio': bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
      'avatar_url': avatarCtrl.text.trim().isEmpty ? null : avatarCtrl.text.trim(),
    };

    specialtyCtrl.dispose();
    levelCtrl.dispose();
    bioCtrl.dispose();
    avatarCtrl.dispose();

    await _runGuarded(() async {
      if (initial == null) {
        await SupabaseService.insert('masters', payload);
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Мастер добавлен');
      } else {
        await SupabaseService.update(
          'masters',
          payload,
          filters: {'id': initial['id']},
        );
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Мастер обновлён');
      }
    });
  }

  Future<void> _openServiceForm({Map<String, dynamic>? initial}) async {
    final nameCtrl = TextEditingController(
      text: (initial?['name'] ?? '').toString(),
    );
    final categoryCtrl = TextEditingController(
      text: (initial?['category'] ?? '').toString(),
    );
    final descriptionCtrl = TextEditingController(
      text: (initial?['description'] ?? '').toString(),
    );
    final durationCtrl = TextEditingController(
      text: (initial?['duration'] ?? '').toString(),
    );
    final priceCtrl = TextEditingController(
      text: (initial?['price'] ?? '').toString(),
    );
    final imageCtrl = TextEditingController(
      text: (initial?['image_url'] ?? '').toString(),
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  initial == null ? 'Новая услуга' : 'Редактирование услуги',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название *'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Категория'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: descriptionCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Длительность (мин)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Цена'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(labelText: 'URL изображения'),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      AppSnackbar.showError(sheetContext, 'Поле "Название" обязательно');
                      return;
                    }
                    Navigator.of(sheetContext).pop(true);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(initial == null ? 'Создать' : 'Сохранить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != true) {
      nameCtrl.dispose();
      categoryCtrl.dispose();
      descriptionCtrl.dispose();
      durationCtrl.dispose();
      priceCtrl.dispose();
      imageCtrl.dispose();
      return;
    }

    final parsedDuration = int.tryParse(durationCtrl.text.trim());
    final parsedPrice = num.tryParse(priceCtrl.text.trim());
    final payload = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'category': categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
      'description':
          descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
      'duration': parsedDuration,
      'price': parsedPrice,
      'image_url': imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
    };

    nameCtrl.dispose();
    categoryCtrl.dispose();
    descriptionCtrl.dispose();
    durationCtrl.dispose();
    priceCtrl.dispose();
    imageCtrl.dispose();

    await _runGuarded(() async {
      if (initial == null) {
        await SupabaseService.insert('services', payload);
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Услуга добавлена');
      } else {
        await SupabaseService.update(
          'services',
          payload,
          filters: {'id': initial['id']},
        );
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Услуга обновлена');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Админ-панель')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Доступ запрещён. Раздел доступен только администраторам.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        leading: const AdminAccessIcon(keepPlaceholderWhenHidden: false),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Мастера'),
            Tab(text: 'Услуги'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadMasters(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Не удалось загрузить мастеров: ${snapshot.error}'),
                  ),
                );
              }
              final masters = snapshot.data ?? const [];
              if (masters.isEmpty) {
                return const Center(child: Text('Мастера пока не добавлены.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  110,
                ),
                itemCount: masters.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = masters[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.surface,
                        backgroundImage: (item['avatar_url'] ?? '').toString().isNotEmpty
                            ? NetworkImage((item['avatar_url'] ?? '').toString())
                            : null,
                        child: (item['avatar_url'] ?? '').toString().isEmpty
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text((item['specialty'] ?? 'Мастер').toString()),
                      subtitle: Text((item['level'] ?? 'Уровень не указан').toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Редактировать',
                            onPressed: _isBusy ? null : () => _openMasterForm(initial: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            onPressed: _isBusy
                                ? null
                                : () {
                                    final id = item['id'];
                                    if (id is int) {
                                      _deleteMaster(id);
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadServices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Не удалось загрузить услуги: ${snapshot.error}'),
                  ),
                );
              }
              final services = snapshot.data ?? const [];
              if (services.isEmpty) {
                return const Center(child: Text('Услуги пока не добавлены.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  110,
                ),
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = services[index];
                  final rawPrice = item['price'];
                  final price = rawPrice is num
                      ? rawPrice.toStringAsFixed(0)
                      : rawPrice.toString();
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: ListTile(
                      title: Text((item['name'] ?? 'Услуга').toString()),
                      subtitle: Text(
                        '${item['category'] ?? 'Без категории'} • ${item['duration'] ?? '-'} мин • $price ₽',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Редактировать',
                            onPressed: _isBusy ? null : () => _openServiceForm(initial: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            onPressed: _isBusy
                                ? null
                                : () {
                                    final id = item['id'];
                                    if (id is int) {
                                      _deleteService(id);
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy
            ? null
            : () {
                if (_tabController.index == 0) {
                  _openMasterForm();
                } else {
                  _openServiceForm();
                }
              },
        icon: Icon(_tabController.index == 0 ? Icons.person_add_alt : Icons.add_box_outlined),
        label: Text(_tabController.index == 0 ? 'Добавить мастера' : 'Добавить услугу'),
      ),
    );
  }
}
