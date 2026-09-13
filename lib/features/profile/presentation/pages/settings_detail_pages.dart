import 'package:flutter/material.dart';
import 'package:seyra/core/constants/app_constants.dart';
import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/storage/local_app_data.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/profile/domain/usecases/change_username_use_case.dart';
import 'package:seyra/features/profile/presentation/widgets/settings_section.dart';

class UsernamePage extends StatefulWidget {
  const UsernamePage({
    super.key,
    required this.currentUsername,
    required this.changeUsername,
  });

  final String currentUsername;
  final ChangeUsernameUseCase changeUsername;

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  late final TextEditingController _controller;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.changeUsername(_controller.text);
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _saving = false;
          _error = switch (failure) {
            UsernameTakenFailure() => 'That username is already taken',
            NetworkFailure() =>
              'Cannot reach the Seyra server. Start the backend, then try again.',
            ValidationFailure() =>
              'Use 3–32 letters, numbers, or underscores. Restart the backend if this keeps failing after a valid name.',
            SessionExpiredFailure() => 'Session expired. Sign in again.',
            _ => failure.message,
          };
        });
      case Success():
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Username'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixText: '@',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
            Text(
            'This is your @username, unique on Seyra. It is not display name or bio (those are on Edit profile). Others start a chat by searching this username. 3–32 letters, numbers, or underscores.',
            style: TextStyle(color: AppColors.hintOf(context)),
          ),
        ],
      ),
    );
  }
}

class EncryptionInfoPage extends StatelessWidget {
  const EncryptionInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('Encryption')),
      body: ListView(
        children: [
          const SettingsSection(
            title: 'What this build protects',
            children: [
              SettingsTile(
                icon: Icons.lock_outline,
                title: '1:1 messages (Signal Protocol)',
                subtitle:
                    'New direct chats use libsignal (X3DH + Double Ratchet) when both sides have published keys. Device id is 1 only — not multi-device E2E.',
              ),
              SettingsTile(
                icon: Icons.attach_file,
                title: '1:1 attachments',
                subtitle:
                    'New direct-file uploads are AES-256-GCM on the device. File keys travel inside the Signal payload. The server stores ciphertext only.',
              ),
              SettingsTile(
                icon: Icons.history,
                title: 'Legacy plaintext',
                subtitle:
                    'Older 1:1 messages and files sent without E2E remain readable on the server. They are not retroactively encrypted.',
              ),
            ],
          ),
          const SettingsSection(
            title: 'Not end-to-end in this build',
            children: [
              SettingsTile(
                icon: Icons.group_outlined,
                title: 'Groups and channels',
                subtitle:
                    'Bodies and files are server-readable plaintext. There is no group ratchet in Seyra.',
              ),
              SettingsTile(
                icon: Icons.call_outlined,
                title: 'Calls',
                subtitle:
                    'WebRTC media uses DTLS-SRTP. There is no extra application-layer call encryption. Signaling is authenticated REST/WebSocket.',
              ),
              SettingsTile(
                icon: Icons.search,
                title: 'Search',
                subtitle:
                    'Server search does not include E2E ciphertext. Plaintext history can appear in search.',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Private keys never leave this device’s secure storage and are never shown in the app. Seyra does not claim universal E2E.',
              style: TextStyle(color: AppColors.hintOf(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({
    super.key,
    required this.onSessions,
    required this.onPrivacy,
    required this.onEncryption,
    this.onBackup,
    this.onRestoreBackup,
  });

  final VoidCallback onSessions;
  final VoidCallback onPrivacy;
  final VoidCallback onEncryption;
  final VoidCallback? onBackup;
  final VoidCallback? onRestoreBackup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: [
          SettingsSection(
            title: 'Available now',
            children: [
              SettingsTile(
                icon: Icons.devices_outlined,
                title: 'Active sessions',
                subtitle: 'Revoke devices signed in to this account',
                onTap: onSessions,
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy controls',
                subtitle: 'Last seen, photos, search, receipts — server-enforced',
                onTap: onPrivacy,
              ),
              SettingsTile(
                icon: Icons.lock_outline,
                title: 'Encryption status',
                subtitle: 'Exact 1:1 Signal coverage and limitations',
                onTap: onEncryption,
              ),
              if (onBackup != null)
                SettingsTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Encrypted backup',
                  subtitle: 'Upload Signal keys encrypted with your passphrase',
                  onTap: onBackup,
                ),
              if (onRestoreBackup != null)
                SettingsTile(
                  icon: Icons.cloud_download_outlined,
                  title: 'Restore backup',
                  subtitle: 'Recover keys after reinstall',
                  onTap: onRestoreBackup,
                ),
            ],
          ),
          const SettingsSection(
            title: 'Account security',
            children: [
              SettingsTile(
                icon: Icons.password,
                title: 'Password',
                subtitle:
                    'Passwords are hashed with Argon2id. Change-password is not in this build — use a unique password and delete the account to retire it.',
              ),
              SettingsTile(
                icon: Icons.key_off_outlined,
                title: 'Passkeys and 2FA',
                subtitle: 'Coming in a future security release — not implemented',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AboutSeyraPage extends StatelessWidget {
  const AboutSeyraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('About Seyra')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text('Version 1.0.0 (1)'),
          const SizedBox(height: 16),
          const Text(
            'Seyra is a private messenger for iOS and Android. This build includes accounts, 1:1 and group/channel chat, bots, WebRTC calls, and Signal-family encryption for new 1:1 conversations when keys exist.',
          ),
          const SizedBox(height: 16),
          Text(
            'Privacy philosophy: the server authorizes every privileged action. Client UI is not a security boundary. We describe encryption only where it is implemented. Legal privacy policy and terms are not published yet.',
            style: TextStyle(color: AppColors.hintOf(context)),
          ),
          const SizedBox(height: 24),
          Text('Open-source licenses', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Third-party packages (Flutter SDK, http, flutter_secure_storage, flutter_webrtc, libsignal_protocol_dart, cryptography, and others) keep their own licenses. Open the repository pubspec and go.mod for the exact set.',
            style: TextStyle(color: AppColors.hintOf(context)),
          ),
        ],
      ),
    );
  }
}

class StorageUsagePage extends StatefulWidget {
  const StorageUsagePage({super.key});

  @override
  State<StorageUsagePage> createState() => _StorageUsagePageState();
}

class _StorageUsagePageState extends State<StorageUsagePage> {
  StorageUsageBreakdown? _usage;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final usage = await LocalAppData.measure();
      if (!mounted) {
        return;
      }
      setState(() {
        _usage = usage;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not measure app-local files';
        _busy = false;
      });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear cache?'),
          content: const Text(
            'Deletes temporary and cache files on this device. Sign-in tokens and encryption identity keys in secure storage are not removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear cache'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await LocalAppData.clearSafeCache();
    await _refresh();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Storage'),
        actions: [
          IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: usage == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _refresh, child: Text(_error!)),
            )
          : ListView(
              children: [
                SettingsSection(
                  title: 'App-local estimate',
                  children: [
                    SettingsTile(
                      icon: Icons.sd_storage_outlined,
                      title: 'Total (this estimate)',
                      subtitle: LocalAppData.formatBytes(usage.totalBytes),
                    ),
                    SettingsTile(
                      icon: Icons.cached_outlined,
                      title: 'Cache',
                      subtitle: LocalAppData.formatBytes(usage.cacheBytes),
                    ),
                    SettingsTile(
                      icon: Icons.folder_outlined,
                      title: 'App support files',
                      subtitle: LocalAppData.formatBytes(usage.supportBytes),
                    ),
                    SettingsTile(
                      icon: Icons.timelapse,
                      title: 'Temporary files',
                      subtitle: LocalAppData.formatBytes(usage.tempBytes),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Storage is an estimate of three folders on this phone: cache, app support, and temp. It is not the operating system “App storage” number (that can include the APK, databases, and secure storage).\n\n'
                    'Clear cache deletes cache and temp only. It does not sign you out, does not delete Signal identity keys, and does not wipe chats in app support.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton(
                    onPressed: _busy ? null : _clear,
                    child: const Text('Clear cache'),
                  ),
                ),
              ],
            ),
    );
  }
}
