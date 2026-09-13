/// Safe profile payload from GET /v1/users/me. Never includes secrets.
final class CurrentAccountModel {
  const CurrentAccountModel({
    required this.id,
    required this.username,
    required this.createdAt,
  });

  final String id;
  final String username;
  final DateTime createdAt;

  factory CurrentAccountModel.fromJson(Map<String, dynamic> json) {
    return CurrentAccountModel(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}
