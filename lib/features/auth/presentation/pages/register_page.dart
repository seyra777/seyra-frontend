import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/usecases/register_use_case.dart';
import 'package:seyra/features/auth/presentation/widgets/auth_pill_button.dart';
import 'package:seyra/features/auth/presentation/widgets/auth_screen_scaffold.dart';
import 'package:seyra/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:seyra/features/auth/presentation/widgets/seyra_auth_header.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.registerUseCase,
    this.onSignIn,
    this.onAuthenticated,
  });

  final RegisterUseCase registerUseCase;
  final VoidCallback? onSignIn;
  final Future<void> Function(AuthSession session, String password)?
      onAuthenticated;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);
    final result = await widget.registerUseCase(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }

    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _submitting = false;
          _errorMessage = failure.message;
        });
      case Success(:final value):
        final password = _passwordController.text;
        try {
          await widget.onAuthenticated?.call(value, password);
        } finally {
          if (mounted) {
            setState(() => _submitting = false);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScreenScaffold(
      showBack: Navigator.of(context).canPop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SeyraAuthHeader(
              compact: true,
              subtitle: 'Create your account',
              detail: 'Join Seyra and start your secure messaging journey.',
            ),
            const SizedBox(height: 28),
            AuthTextField(
              key: const Key('register_username_field'),
              controller: _usernameController,
              label: 'Username',
              prefixIcon: Icons.person_outline,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              key: const Key('register_password_field'),
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline,
              obscureable: true,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              key: const Key('register_confirm_password_field'),
              controller: _confirmPasswordController,
              label: 'Confirm password',
              prefixIcon: Icons.lock_outline,
              obscureable: true,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm password is required';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                key: const Key('register_error_message'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            AuthGradientButton(
              key: const Key('register_submit_button'),
              label: 'Create Account',
              icon: Icons.add,
              busy: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                style: theme.textTheme.bodyMedium,
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: TextButton(
                      onPressed: _submitting ? null : widget.onSignIn,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign in'),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
