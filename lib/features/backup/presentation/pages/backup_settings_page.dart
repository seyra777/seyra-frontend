import 'package:flutter/material.dart';
import 'package:seyra/core/services/backup_api_service.dart';
import 'package:seyra/core/services/backup_service.dart';
import 'package:seyra/core/theme/app_colors.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({
    super.key,
    required this.userId,
    required this.backupService,
  });

  final String userId;
  final BackupService backupService;

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  var _busy = false;
  var _hasRemoteBackup = false;
  DateTime? _updatedAt;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final hasBackup = await widget.backupService.hasRemoteBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _hasRemoteBackup = hasBackup;
        _message = hasBackup
            ? 'Encrypted backup is stored on the server.'
            : 'No cloud backup yet.';
      });
    } on BackupApiException catch (error) {
      if (mounted) {
        setState(() => _message = error.message.isEmpty ? error.code : error.message);
      }
    }
  }

  Future<void> _upload() async {
    final passphrase = _passphraseController.text;
    final confirm = _confirmController.text;
    if (passphrase.length < 8) {
      setState(() => _message = 'Use at least 8 characters.');
      return;
    }
    if (passphrase != confirm) {
      setState(() => _message = 'Passphrases do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updatedAt = await widget.backupService.uploadBackup(
        userId: widget.userId,
        passphrase: passphrase,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _hasRemoteBackup = true;
        _updatedAt = updatedAt;
        _message = 'Backup uploaded. Only you can decrypt it with your passphrase.';
        _passphraseController.clear();
        _confirmController.clear();
      });
    } on StateError catch (error) {
      setState(() => _message = error.message);
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    } on BackupApiException catch (error) {
      setState(() => _message = error.message.isEmpty ? error.code : error.message);
    } catch (_) {
      setState(() => _message = 'Backup upload failed.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.backupService.deleteRemoteBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _hasRemoteBackup = false;
        _updatedAt = null;
        _message = 'Cloud backup deleted.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not delete backup.');
      }
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
      appBar: AppBar(title: const Text('Encrypted backup')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Seyra also auto-backs up encryption keys using your account password when you sign in. This screen is an optional extra passphrase backup.',
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
          if (_updatedAt != null) ...[
            const SizedBox(height: 8),
            Text('Last upload: ${_updatedAt!.toLocal()}'),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _passphraseController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Backup passphrase',
              helperText: 'Remember this — it cannot be recovered.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm passphrase',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _upload,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_hasRemoteBackup ? 'Replace cloud backup' : 'Upload backup'),
          ),
          if (_hasRemoteBackup) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _delete,
              child: const Text('Delete cloud backup'),
            ),
          ],
        ],
      ),
    );
  }
}
