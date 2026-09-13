import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:seyra/core/network/api_client.dart';

final class HttpApiClient implements ApiClient {
  HttpApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final request = http.Request(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (jsonBody != null) 'Content-Type': 'application/json',
      ...?headers,
    });
    if (jsonBody != null) {
      request.body = jsonEncode(jsonBody);
    }

    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();
    return ApiResponse(statusCode: streamed.statusCode, body: body);
  }
}
