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

final class RegistrationPage extends ConsumerStatefulWidget {
  const RegistrationPage({super.key});

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

final class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _formError;
  String? _emailError;
  String? _passwordError;

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
      _emailError = null;
      _passwordError = null;
    });

    try {
      // FRONTEND-BACKEND: Registration uses the approved email/password endpoint.
      final tokens = await ref
          .read(authenticationApiProvider)
          .register(
            RegistrationRequest(
              email: _emailController.text.trim(),
              // Passwords are intentionally not trimmed or normalized on the client.
              password: _passwordController.text,
            ),
          );
      await ref.read(sessionControllerProvider.notifier).establish(tokens);

      if (!mounted) {
        return;
      }
      context.go('/onboarding');
    } on ApiError catch (error) {
      if (mounted) {
        _showApiError(error);
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

  void _showApiError(ApiError error) {
    String? emailError;
    String? passwordError;
    for (final detail in error.details) {
      if (detail.field == 'email') {
        emailError = detail.message;
      } else if (detail.field == 'password') {
        passwordError = detail.message;
      }
    }

    setState(() {
      _formError = error.message;
      _emailError = emailError;
      _passwordError = passwordError;
    });
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
                            'Create your account',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start building a healthier routine with Kalonet.',
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
                            autofillHints: const [AutofillHints.email],
                            validator: _validateEmail,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
                              prefixIcon: const Icon(Icons.mail_outline),
                              errorText: _emailError,
                            ),
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: _validatePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'At least 15 characters',
                              prefixIcon: const Icon(Icons.lock_outline),
                              errorText: _passwordError,
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
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Use a unique passphrase. Kalonet accepts spaces and password-manager input.',
                            style: textTheme.bodySmall?.copyWith(
                              color: KalonetColors.textSecondary,
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
                                : const Text('Create account'),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Email and password authentication are supported for the Kalonet MVP.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: KalonetColors.textSecondary,
                            ),
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
