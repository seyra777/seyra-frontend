/// Network transport boundary.
///
/// Staging and production implementations must use TLS.
/// Do not call this from UI.
final class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  bool get isNoContent => statusCode == 204 || body.trim().isEmpty;
}

abstract interface class ApiClient {
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? jsonBody,
  });
}
