import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/storage/secure_storage.dart';
import 'package:seyra/features/chat/domain/usecases/watch_incoming_alerts_use_case.dart';
import 'package:seyra/features/notifications/data/notification_display.dart';
import 'package:seyra/features/notifications/domain/usecases/notification_use_cases.dart';

/// Binds device registration and OS alerts. Widgets do not call this directly
/// except from the composition root / signed-in shell.
final class PushCoordinator {
  PushCoordinator({
    required this.registerDevice,
    required this.unregisterDevice,
    required this.watchAlerts,
    required this.display,
    required this.secureStorage,
    required this.openConversation,
  });

  final RegisterDeviceUseCase registerDevice;
  final UnregisterDeviceUseCase unregisterDevice;
  final WatchIncomingAlertsUseCase watchAlerts;
  final NotificationDisplay display;
  final SecureStorage secureStorage;
  final void Function(String conversationId) openConversation;

  static const _tokenKey = 'seyra.push.device_token';
  static const _idKey = 'seyra.push.device_id';

  StreamSubscription<dynamic>? _sub;
  var _started = false;

  bool get isStarted => _started;

  String get platformLabel {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'Android'
        : 'This platform';
  }

  Future<bool> hasServerDevice() async {
    final id = await secureStorage.read(_idKey);
    return id != null && id.isNotEmpty;
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    await display.initialize(onTapConversation: openConversation);
    await display.requestPermission();
    final token = await _deviceToken();
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : 'dev';
    final result = await registerDevice(platform: platform, token: token);
    if (result is Success<String>) {
      await secureStorage.write(key: _idKey, value: result.value);
    }
    _sub = watchAlerts().listen(display.show);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
    final id = await secureStorage.read(_idKey);
    if (id != null && id.isNotEmpty) {
      await unregisterDevice(id);
    }
  }

  Future<String> _deviceToken() async {
    final existing = await secureStorage.read(_tokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final token = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await secureStorage.write(key: _tokenKey, value: token);
    return token;
  }
}
