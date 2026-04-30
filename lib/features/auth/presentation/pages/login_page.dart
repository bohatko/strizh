import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/theme.dart';
import 'package:app_template/core/ui/app_button.dart';
import 'package:app_template/core/ui/app_text_field.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/core/logging/app_logger.dart';

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
        if (mounted) {
          context.go('/home');
        }
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
      _showSnack('Please enter email and password');
      return;
    }

    FocusScope.of(context).unfocus();
    AppLogger.info('Auth submit requested (isSignUp=$_isSignUp)');
    final notifier = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      await notifier.signUpWithEmailPassword(email: email, password: password);
    } else {
      await notifier.signInWithEmailPassword(email: email, password: password);
    }
  }

  String _prettyError(Object error) {
    final raw = error.toString();
    if (raw.contains('Failed to decode error response')) {
      return 'Sign-in failed. This often means the Supabase response was not JSON (network/CORS/proxy issue). Please check your Supabase project URL and that the app can reach it.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackbar.showError(context, message);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Reset password', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'We will email you a password reset link.',
                  style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.mail_outline),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Send link',
                  onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          );
        },
      );

      if (email == null || email.isEmpty) return;
      await ref.read(authControllerProvider.notifier).resetPassword(email);
      _showSnack('Reset link sent (check your email)');
    } catch (e) {
      AppLogger.error('Reset password failed', error: e);
      _showSnack(e.toString());
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authAsync = ref.watch(authControllerProvider);
    final isBusy = authAsync.isLoading;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              _BrandHeader(),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                controller: _emailCtrl,
                label: 'Email Address',
                hint: 'name@company.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _passwordCtrl,
                label: 'Password',
                hint: '********',
                icon: Icons.lock_outline,
                obscureText: _obscure,
                keyboardType: TextInputType.visiblePassword,
                suffix: IconButton(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: ButtonStyle(splashFactory: NoSplash.splashFactory),
                  onPressed: isBusy ? null : _forgotPassword,
                  child: Text(
                    'Forgot Password?',
                    style: Theme.of(context).textTheme.labelLarge?.withColor(cs.tertiary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isSignUp ? 'Create Account' : 'Sign In',
                onPressed: isBusy ? null : _submit,
                isLoading: isBusy,
              ),
              const SizedBox(height: AppSpacing.xl),
              _OrDivider(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _SocialButton(
                      label: 'Google',
                      icon: Icons.g_mobiledata,
                      onPressed: () => _showSnack('Google Sign-In is not configured in this boilerplate.'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _SocialButton(
                      label: 'Apple',
                      icon: Icons.apple,
                      onPressed: () => _showSnack('Apple Sign-In is not configured in this boilerplate.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp ? 'Already have an account?' : "Don't have an account?",
                    style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    style: ButtonStyle(splashFactory: NoSplash.splashFactory),
                    onPressed: isBusy ? null : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Sign In' : 'Create Account',
                      style: Theme.of(context).textTheme.bodyMedium?.semiBold.withColor(cs.tertiary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'By signing in, you agree to our Terms of Service and Privacy Policy',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          ),
          child: Icon(Icons.description_outlined, size: 34, color: cs.onSurface),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('InvoicePro', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Professional Billing Made Simple',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.25), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or continue with',
            style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.25), height: 1)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SocialButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      style: ButtonStyle(
        splashFactory: NoSplash.splashFactory,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 14)),
        side: WidgetStatePropertyAll(BorderSide(color: cs.outline.withValues(alpha: 0.25))),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: cs.onSurface),
      label: Text(label, style: Theme.of(context).textTheme.labelLarge?.withColor(cs.onSurface)),
    );
  }
}
