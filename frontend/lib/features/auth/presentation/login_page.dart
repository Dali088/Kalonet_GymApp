import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/errors/api_error.dart';
import '../../../core/theme/kalonet_colors.dart';
import '../../../core/widgets/kalonet_auth_scaffold.dart';
import '../../../core/widgets/kalonet_brand_mark.dart';
import '../authentication_models.dart';
import '../authentication_providers.dart';

final class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      // FRONTEND-BACKEND: Login uses the approved email/password session endpoint.
      final tokens = await ref
          .read(authenticationApiProvider)
          .login(
            LoginRequest(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
      await ref.read(sessionControllerProvider.notifier).establish(tokens);

      if (!mounted) {
        return;
      }
      context.go(
        tokens.user.onboardingCompleted ? '/dashboard' : '/onboarding',
      );
    } on ApiError catch (error) {
      if (mounted) {
        setState(() {
          _formError = error.message;
        });
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          _formError = 'The server returned an unexpected response.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return KalonetAuthScaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = (constraints.maxWidth - 48)
                .clamp(0.0, 420.0)
                .toDouble();
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: contentWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.center,
                            child: KalonetBrandMark(size: 72),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Log in to continue your Kalonet journey.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: KalonetColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (_formError != null) ...[
                            _ErrorBanner(message: _formError!),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            validator: _validateEmail,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: _validatePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go('/forgot-password'),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Log in'),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KalonetColors.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KalonetColors.errorBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(color: KalonetColors.errorText),
      ),
    );
  }
}
