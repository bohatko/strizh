import 'package:app_template/core/logging/app_logger.dart';
import 'package:app_template/core/ui/app_button.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isSignUp = false;
  bool _awaitingRequiredProfile = false;
  bool _profileSheetShown = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authControllerProvider, (prev, next) {
      final prevError = prev?.error;
      final nextError = next.error;
      if (nextError != null && nextError != prevError) {
        AppLogger.warning('Auth UI received error', error: nextError);
        _showSnack(_prettyError(nextError));
      }

      final prevState = prev?.maybeWhen<AuthState?>(
        data: (value) => value,
        orElse: () => null,
      );
      final nextState = next.maybeWhen<AuthState?>(
        data: (value) => value,
        orElse: () => null,
      );

      if (nextState is Authenticated && prevState is! Authenticated) {
        if (!mounted) return;

        if (_awaitingRequiredProfile) {
          if (_profileSheetShown) return;
          _profileSheetShown = true;
          _showRequiredProfileSheet();
          return;
        }

        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Введите email и пароль');
      return;
    }

    if (_isSignUp && password.length < 6) {
      _showSnack('Пароль должен быть не менее 6 символов');
      return;
    }

    FocusScope.of(context).unfocus();
    AppLogger.info('Auth submit requested (isSignUp=$_isSignUp)');
    final notifier = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      _awaitingRequiredProfile = true;
      _profileSheetShown = false;
      await notifier.signUpWithEmailPassword(email: email, password: password);
      return;
    }

    _awaitingRequiredProfile = false;
    await notifier.signInWithEmailPassword(email: email, password: password);
  }

  Future<void> _forgotPassword() async {
    final cs = Theme.of(context).colorScheme;
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    try {
      final email = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Сброс пароля', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Мы отправим ссылку для сброса на вашу почту.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Эл. почта',
                    prefixIcon: const Icon(Icons.mail_outline),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Отправить ссылку',
                  onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
                ),
              ],
            ),
          );
        },
      );

      if (email == null || email.isEmpty) return;
      await ref.read(authControllerProvider.notifier).resetPassword(email);
      _showSnack('Ссылка для сброса отправлена');
    } catch (e) {
      AppLogger.error('Reset password failed', error: e);
      _showSnack(e.toString());
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _showRequiredProfileSheet() async {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+7 ');
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    Future<void> submitProfile(StateSetter setSheetState) async {
      final isValid = formKey.currentState?.validate() ?? false;
      if (!isValid) return;

      final normalizedPhone = _normalizeRuPhone(phoneCtrl.text);
      if (normalizedPhone == null) return;

      setSheetState(() => isSaving = true);
      try {
        final firstName = firstNameCtrl.text.trim();
        final lastName = lastNameCtrl.text.trim();

        await ref.read(authControllerProvider.notifier).updateProfile(
              firstName: firstName,
              lastName: lastName,
              displayName: '$firstName $lastName',
              phoneNumber: normalizedPhone,
            );

        if (!mounted) return;
        _awaitingRequiredProfile = false;
        Navigator.of(context).pop();
        context.go('/home');
      } catch (e) {
        if (!mounted) return;
        AppSnackbar.showError(context, 'Не удалось сохранить профиль: $e');
      } finally {
        if (mounted) {
          setSheetState(() => isSaving = false);
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFFFEF7FF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Завершение регистрации',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF6D4EA2),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Введите имя, фамилию и номер телефона РФ.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A4550),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        controller: firstNameCtrl,
                        hint: 'Имя',
                        icon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите имя';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _ProfileField(
                        controller: lastNameCtrl,
                        hint: 'Фамилия',
                        icon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите фамилию';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _ProfileField(
                        controller: phoneCtrl,
                        hint: '+7 999 123-45-67',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\(\)\s]')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите номер телефона';
                          }
                          if (_normalizeRuPhone(value) == null) {
                            return 'Введите корректный номер РФ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Завершить регистрацию',
                        onPressed: isSaving ? null : () => submitProfile(setSheetState),
                        isLoading: isSaving,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
    _profileSheetShown = false;
  }

  String? _normalizeRuPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+7$digits';
    if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
      return '+7${digits.substring(1)}';
    }
    return null;
  }

  String _prettyError(Object error) {
    final raw = error.toString();
    if (raw.contains('Failed to decode error response')) {
      return 'Ошибка входа. Проверьте подключение к Supabase и настройки проекта.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackbar.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authControllerProvider);
    final isBusy = authAsync.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 90),
                    Text(
                      'Стриж',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: const Color(0xFF6D4EA2),
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Добро пожаловать',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4A4550),
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _AuthTabs(
                      isSignUp: _isSignUp,
                      onChanged: isBusy
                          ? null
                          : (value) => setState(() {
                                _isSignUp = value;
                                _awaitingRequiredProfile = false;
                              }),
                    ),
                    const SizedBox(height: 12),
                    _AuthInput(
                      controller: _emailCtrl,
                      hint: 'Эл. почта',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _AuthInput(
                      controller: _passwordCtrl,
                      hint: 'Пароль',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      suffix: IconButton(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF7B7581),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: ButtonStyle(splashFactory: NoSplash.splashFactory),
                        onPressed: isBusy ? null : _forgotPassword,
                        child: const Text(
                          'Забыли пароль?',
                          style: TextStyle(color: Color(0xFF6D4EA2), fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: _isSignUp ? 'Зарегистрироваться' : 'Войти',
                      onPressed: isBusy ? null : _submit,
                      isLoading: isBusy,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp ? 'Уже есть аккаунт?' : 'Нет аккаунта?',
                          style: const TextStyle(
                            color: Color(0xFF4A4550),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: isBusy
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _awaitingRequiredProfile = false;
                                  }),
                          child: Text(
                            _isSignUp ? 'Войти' : 'Зарегистрироваться',
                            style: const TextStyle(
                              color: Color(0xFF6D4EA2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTabs extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool>? onChanged;

  const _AuthTabs({
    required this.isSignUp,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E0E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _TabButton(
            text: 'Вход',
            isSelected: !isSignUp,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
          _TabButton(
            text: 'Регистрация',
            isSelected: isSignUp,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.75) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF4A4550),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _AuthInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1FA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05333333),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: Color(0xFF1D1A20)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF7B7581), fontSize: 16),
          prefixIcon: Icon(icon, color: const Color(0xFF7B7581)),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _ProfileField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF7B7581)),
        filled: true,
        fillColor: const Color(0xFFF8F1FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
