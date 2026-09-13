import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/auth/domain/usecases/delete_account_use_case.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    required this.deleteAccount,
    required this.onDeleted,
  });

  final DeleteAccountUseCase deleteAccount;
  final VoidCallback onDeleted;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  static const _confirmationPhrase = 'DELETE';

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _obscurePassword = true;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return !_submitting &&
        _passwordController.text.isNotEmpty &&
        _confirmController.text == _confirmationPhrase;
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.deleteAccount(
      password: _passwordController.text,
    );
    _passwordController.clear();
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success():
        widget.onDeleted();
      case FailureResult(:final failure):
        setState(() {
          _submitting = false;
          _error = switch (failure) {
            InvalidCredentialsFailure() => 'Current password is incorrect',
            UnauthorizedFailure() || SessionExpiredFailure() =>
              'Please sign in again',
            _ => failure.message,
          };
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Delete account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.dangerFillOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.dangerBorderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.dangerTitleOf(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'This cannot be undone',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.dangerTitleOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deleting your Seyra account is permanent. Your username, '
                    'profile, sessions, and bot tokens are removed. Chat history '
                    'for other members may remain with your sender identity cleared. '
                    'This cannot be undone. You must re-enter your password.',
                    style: TextStyle(
                      height: 1.4,
                      color: AppColors.dangerBodyOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Type $_confirmationPhrase to confirm',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('delete_account_confirm_text_field'),
            controller: _confirmController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: _confirmationPhrase,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text(
            'Enter your current password',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('delete_account_password_field'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: AppColors.dangerOf(context)),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('delete_account_confirm_button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerOf(context),
              disabledBackgroundColor: AppColors.isDark(context)
                  ? AppColors.darkDivider
                  : AppColors.fieldBorder,
              disabledForegroundColor: AppColors.hintOf(context),
            ),
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Permanently delete account'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('delete_account_cancel_button'),
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
