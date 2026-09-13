import 'package:flutter/material.dart';
import 'package:seyra/core/services/backup_api_service.dart';
import 'package:seyra/core/services/backup_service.dart';
import 'package:seyra/core/theme/app_colors.dart';

class RestoreBackupPage extends StatefulWidget {
  const RestoreBackupPage({
    super.key,
    required this.userId,
    required this.backupService,
    this.onRestored,
  });

  final String userId;
  final BackupService backupService;
  final VoidCallback? onRestored;

  @override
  State<RestoreBackupPage> createState() => _RestoreBackupPageState();
}

class _RestoreBackupPageState extends State<RestoreBackupPage> {
  final _passphraseController = TextEditingController();
  var _busy = false;
  var _hasRemoteBackup = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _checkBackup();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _checkBackup() async {
    try {
      final hasBackup = await widget.backupService.hasRemoteBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _hasRemoteBackup = hasBackup;
        _message = hasBackup
            ? 'A cloud backup exists for this account.'
            : 'No cloud backup found for this account.';
      });
    } on BackupApiException catch (error) {
      if (mounted) {
        setState(() => _message = error.message.isEmpty ? error.code : error.message);
      }
    }
  }

  Future<void> _restore() async {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() => _message = 'Enter your backup passphrase.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.backupService.restoreBackup(
        userId: widget.userId,
        passphrase: passphrase,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message =
            'Backup restored. Your encrypted chats should decrypt after history reloads.';
      });
      widget.onRestored?.call();
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    } on BackupApiException catch (error) {
      setState(() => _message = error.message.isEmpty ? error.code : error.message);
    } catch (_) {
      setState(() => _message = 'Restore failed.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('Restore backup')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'After reinstall, download your encrypted backup and restore Signal keys on this device. Messages stay encrypted on the server.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedOf(context),
                ),
          ),
          const SizedBox(height: 16),
          if (_message != null)
            Text(
              _message!,
              style: TextStyle(color: AppColors.accentOf(context)),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _passphraseController,
            obscureText: true,
            enabled: _hasRemoteBackup && !_busy,
            decoration: const InputDecoration(
              labelText: 'Backup passphrase',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: !_hasRemoteBackup || _busy ? null : _restore,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Download and restore'),
          ),
        ],
      ),
    );
  }
}
