import 'dart:io';

import 'package:flutter/services.dart';

const _deviceChannel = MethodChannel('seyra/device');

Future<({String platform, String environment})> detectCallRuntime() async {
  if (Platform.isAndroid) {
    return (
      platform: 'android',
      environment: await _isAndroidEmulator() ? 'emulator' : 'device',
    );
  }
  if (Platform.isIOS) {
    return (platform: 'ios', environment: 'device');
  }
  return (platform: Platform.operatingSystem, environment: 'host');
}

Future<bool> _isAndroidEmulator() async {
  try {
    final native = await _deviceChannel.invokeMethod<bool>('isEmulator');
    if (native == true) {
      return true;
    }
  } catch (_) {}
  try {
    final cpu = (await File('/proc/cpuinfo').readAsString()).toLowerCase();
    if (cpu.contains('goldfish') || cpu.contains('ranchu')) {
      return true;
    }
  } catch (_) {}
  try {
    if (await File('/dev/qemu_pipe').exists()) {
      return true;
    }
  } catch (_) {}
  return false;
}
