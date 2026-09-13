Future<({String platform, String environment})> detectCallRuntime() async {
  return (platform: 'web', environment: 'browser');
}
