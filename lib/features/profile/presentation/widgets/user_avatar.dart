import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/core/theme/app_colors.dart';

class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.userId,
    required this.initials,
    this.radius = 24,
    this.hasAvatar = true,
  });

  final String userId;
  final String initials;
  final double radius;
  final bool hasAvatar;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Uint8List? _bytes;
  var _tried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.hasAvatar != widget.hasAvatar) {
      _tried = false;
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.hasAvatar || widget.userId.isEmpty || _tried) {
      return;
    }
    _tried = true;
    final bytes = await AppDependencies.profileRepository.fetchAvatar(
      widget.userId,
    );
    if (!mounted) {
      return;
    }
    if (bytes != null && bytes.isNotEmpty) {
      setState(() => _bytes = Uint8List.fromList(bytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.avatarFillOf(context),
      backgroundImage: _bytes == null ? null : MemoryImage(_bytes!),
      child: _bytes == null
          ? Text(
              widget.initials.isEmpty
                  ? '?'
                  : widget.initials.substring(0, widget.initials.length.clamp(0, 2)),
              style: TextStyle(
                color: AppColors.avatarFgOf(context),
                fontWeight: FontWeight.w700,
                fontSize: widget.radius * 0.7,
              ),
            )
          : null,
    );
  }
}
