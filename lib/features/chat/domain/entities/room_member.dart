enum MemberRole { owner, admin, member }

MemberRole memberRoleFromApi(String? value) {
  return switch (value) {
    'owner' => MemberRole.owner,
    'admin' => MemberRole.admin,
    _ => MemberRole.member,
  };
}

final class RoomMember {
  const RoomMember({
    required this.id,
    required this.username,
    required this.role,
  });

  final String id;
  final String username;
  final MemberRole role;

  String get roleLabel => switch (role) {
    MemberRole.owner => 'Owner',
    MemberRole.admin => 'Admin',
    MemberRole.member => 'Member',
  };
}
