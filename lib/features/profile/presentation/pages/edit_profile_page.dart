import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seyra/core/errors/failures.dart';
import 'package:seyra/core/errors/network_failure.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/auth/domain/entities/user.dart';
import 'package:seyra/features/auth/domain/failures/auth_failures.dart';
import 'package:seyra/features/auth/presentation/widgets/auth_pill_button.dart';
import 'package:seyra/features/profile/domain/entities/user_profile.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';
import 'package:seyra/features/profile/domain/usecases/update_profile_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/watch_profile_use_case.dart';
import 'package:seyra/features/profile/presentation/widgets/user_avatar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.user,
    required this.watchProfile,
    required this.updateProfile,
    required this.profileRepository,
    this.onUsername,
  });

  final User user;
  final WatchProfileUseCase watchProfile;
  final UpdateProfileUseCase updateProfile;
  final ProfileRepository profileRepository;
  final VoidCallback? onUsername;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  UserProfile? _profile;
  bool _saving = false;
  bool _uploading = false;
  String? _error;
  StreamSubscription<UserProfile>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget
        .watchProfile(userId: widget.user.id, username: widget.user.username)
        .listen((profile) {
          if (!mounted) {
            return;
          }
          if (_profile == null) {
            _displayName.text = profile.displayName;
            _bio.text = profile.bio;
          }
          setState(() => _profile = profile);
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.updateProfile(
      userId: widget.user.id,
      displayName: _displayName.text,
      bio: _bio.text,
    );
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _saving = false;
          _error = switch (failure) {
            NetworkFailure() =>
              'Cannot reach the Seyra server. Start the backend, then tap Save again.',
            ValidationFailure() =>
              'The server rejected this save. Restart the backend so profile APIs and migration 013 are loaded.',
            SessionExpiredFailure() => 'Session expired. Sign in again.',
            _ => failure.message,
          };
        });
      case Success():
        Navigator.of(context).pop();
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    final bytes = await picked.readAsBytes();
    final result = await widget.profileRepository.uploadAvatar(
      bytes: bytes,
      filename: picked.name,
      contentType: picked.mimeType ?? 'image/jpeg',
    );
    if (!mounted) {
      return;
    }
    setState(() => _uploading = false);
    if (result is FailureResult<UserProfile>) {
      setState(() {
        _error = switch (result.failure) {
          NetworkFailure() =>
            'Cannot reach the Seyra server. Restart the backend, then try Change photo again.',
          ValidationFailure() =>
            'The photo could not be saved. Restart the backend so avatar uploads are allowed, then try again.',
          _ => result.failure.message,
        };
      });
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploading = true);
    await widget.profileRepository.removeAvatar();
    if (mounted) {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            key: const Key('edit_profile_save_button'),
            onPressed: profile != null && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      UserAvatar(
                        userId: profile.userId,
                        initials: profile.displayName.isEmpty
                            ? profile.username
                            : profile.displayName,
                        radius: 48,
                        hasAvatar: profile.hasAvatar,
                      ),
                      if (_uploading)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _uploading ? null : _pickPhoto,
                      child: const Text('Change photo'),
                    ),
                    if (profile.hasAvatar)
                      TextButton(
                        onPressed: _uploading ? null : _removePhoto,
                        child: const Text('Remove'),
                      ),
                  ],
                ),
                TextField(
                  key: const Key('edit_profile_display_name_field'),
                  controller: _displayName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('edit_profile_bio_field'),
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onUsername,
                  child: const Text('Change username'),
                ),
                Text(
                  'Display name and bio are not your @username. Username is unique and is how others start a chat with you.',
                  style: TextStyle(color: AppColors.hintOf(context)),
                ),
                const SizedBox(height: 28),
                AuthGradientButton(
                  label: 'Save',
                  busy: _saving,
                  onPressed: !_saving ? _save : null,
                ),
              ],
            ),
    );
  }
}
