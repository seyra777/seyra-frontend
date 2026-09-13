import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/auth/domain/entities/auth_session.dart';
import 'package:seyra/features/auth/domain/usecases/login_use_case.dart';
import 'package:seyra/features/auth/presentation/widgets/auth_pill_button.dart';
import 'package:seyra/features/auth/presentation/widgets/auth_screen_scaffold.dart';
import 'package:seyra/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:seyra/features/auth/presentation/widgets/seyra_auth_header.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.loginUseCase,
    this.onCreateAccount,
    this.onAuthenticated,
  });

  final LoginUseCase loginUseCase;
  final VoidCallback? onCreateAccount;
  final Future<void> Function(AuthSession session, String password)?
      onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);
    final result = await widget.loginUseCase(
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
    final canPop = Navigator.of(context).canPop();

    return AuthScreenScaffold(
      showBack: canPop,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SeyraAuthHeader(
              compact: true,
              subtitle: 'Welcome back',
              detail: null,
            ),
            const SizedBox(height: 48),
            AuthTextField(
              key: const Key('login_username_field'),
              controller: _usernameController,
              label: 'Username',
              prefixIcon: Icons.person_outline,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthTextField(
              key: const Key('login_password_field'),
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline,
              obscureable: true,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                key: const Key('login_error_message'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const Spacer(),
            const SizedBox(height: 32),
            AuthGradientButton(
              key: const Key('login_submit_button'),
              label: 'Sign in',
              icon: Icons.person_outline,
              busy: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 14),
            AuthOutlinedPillButton(
              onPressed: _submitting ? null : widget.onCreateAccount,
              icon: Icons.add,
              label: 'Create an account',
            ),
          ],
        ),
      ),
    );
  }
}
