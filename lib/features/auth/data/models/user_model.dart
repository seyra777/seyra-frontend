import 'package:seyra/features/auth/domain/entities/user.dart';

final class UserModel {
  const UserModel({
    required this.id,
    required this.username,
  });

  final String id;
  final String username;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }

  User toEntity() => User(id: id, username: username);
}
