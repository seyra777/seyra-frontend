final class User {
  const User({
    required this.id,
    required this.username,
  });

  final String id;
  final String username;

  @override
  bool operator ==(Object other) {
    return other is User && other.id == id && other.username == username;
  }

  @override
  int get hashCode => Object.hash(id, username);
}
