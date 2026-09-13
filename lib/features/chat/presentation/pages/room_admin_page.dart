import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';
import 'package:seyra/features/chat/domain/usecases/room_member_use_cases.dart';
import 'package:seyra/features/profile/presentation/widgets/settings_section.dart';

/// Group/channel administrators. Server roles stay the source of truth.
class RoomAdminPage extends StatefulWidget {
  const RoomAdminPage({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.listMembers,
    required this.addMembers,
    required this.removeMember,
    required this.setMemberRole,
    this.social,
  });

  final Conversation conversation;
  final String currentUserId;
  final ListMembersUseCase listMembers;
  final AddMembersUseCase addMembers;
  final RemoveMemberUseCase removeMember;
  final SetMemberRoleUseCase setMemberRole;
  final ChatSocialRepository? social;

  @override
  State<RoomAdminPage> createState() => _RoomAdminPageState();
}

class _RoomAdminPageState extends State<RoomAdminPage> {
  var _loading = true;
  String? _error;
  List<RoomMember> _members = const [];

  MemberRole get _myRole {
    for (final member in _members) {
      if (member.id == widget.currentUserId) {
        return member.role;
      }
    }
    return MemberRole.member;
  }

  bool get _canManage =>
      _myRole == MemberRole.owner || _myRole == MemberRole.admin;

  bool get _isOwner => _myRole == MemberRole.owner;

  List<RoomMember> get _admins => _members
      .where(
        (member) =>
            member.role == MemberRole.owner || member.role == MemberRole.admin,
      )
      .toList();

  List<RoomMember> get _regularMembers => _members
      .where((member) => member.role == MemberRole.member)
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.listMembers(widget.conversation.id);
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _loading = false;
          _error = failure.message;
        });
      case Success(:final value):
        setState(() {
          _loading = false;
          _members = value;
        });
    }
  }

  Future<void> _addMember() async {
    final username = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add member'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Username'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (username == null || username.isEmpty) {
      return;
    }
    final result = await widget.addMembers(
      conversationId: widget.conversation.id,
      usernames: [username],
    );
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      case Success(:final value):
        setState(() => _members = value);
    }
  }

  Future<void> _promoteMember() async {
    if (_regularMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a member first, then promote them.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<RoomMember>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Promote to admin')),
              for (final member in _regularMembers)
                ListTile(
                  title: Text(member.username),
                  onTap: () => Navigator.pop(context, member),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) {
      return;
    }
    await widget.setMemberRole(
      conversationId: widget.conversation.id,
      userId: picked.id,
      role: MemberRole.admin,
    );
    await _load();
  }

  Future<void> _createInvite() async {
    final social = widget.social;
    if (social == null) {
      return;
    }
    final result = await social.createInvite(widget.conversation.id);
    if (!mounted) {
      return;
    }
    final text = result is Success<String>
        ? result.value
        : (result as FailureResult).failure.message;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.conversation.kind == ConversationKind.channel
        ? 'channel'
        : 'group';
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('Administrators')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Owner and admins of this $kind. Only the owner can promote or demote admins. The server enforces every change.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                SettingsSection(
                  title: 'Administrators',
                  children: [
                    if (_isOwner)
                      SettingsTile(
                        key: const Key('add_administrator'),
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Add administrator',
                        subtitle: 'Promote a member',
                        onTap: _promoteMember,
                      ),
                    if (_canManage)
                      SettingsTile(
                        icon: Icons.person_add_outlined,
                        title: 'Add member',
                        subtitle: 'They join as a member',
                        onTap: _addMember,
                      ),
                    if (_canManage && widget.social != null)
                      SettingsTile(
                        icon: Icons.link,
                        title: 'Invite link',
                        subtitle: 'Create a join token',
                        onTap: _createInvite,
                      ),
                    for (final member in _admins) _memberTile(context, member),
                  ],
                ),
                if (_regularMembers.isNotEmpty)
                  SettingsSection(
                    title: 'Members',
                    children: [
                      for (final member in _regularMembers)
                        _memberTile(context, member),
                    ],
                  ),
                if (!_canManage)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'You can view administrators. Member management requires owner or admin.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _memberTile(BuildContext context, RoomMember member) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.mutedOf(context),
        child: Text(
          member.username.isEmpty ? '?' : member.username[0].toUpperCase(),
          style: TextStyle(color: AppColors.textOf(context)),
        ),
      ),
      title: Text(
        member.id == widget.currentUserId
            ? '${member.username} (you)'
            : member.username,
      ),
      subtitle: Text(member.roleLabel),
      trailing: _memberMenu(member),
    );
  }

  Widget? _memberMenu(RoomMember member) {
    if (member.id == widget.currentUserId || member.role == MemberRole.owner) {
      return null;
    }
    final canRemove =
        _myRole == MemberRole.owner ||
        (_myRole == MemberRole.admin && member.role == MemberRole.member);
    final canPromote = _myRole == MemberRole.owner;
    if (!canRemove && !canPromote) {
      return null;
    }
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'remove') {
          final result = await widget.removeMember(
            conversationId: widget.conversation.id,
            userId: member.id,
          );
          if (result is Success) {
            await _load();
          }
        } else if (value == 'admin') {
          await widget.setMemberRole(
            conversationId: widget.conversation.id,
            userId: member.id,
            role: MemberRole.admin,
          );
          await _load();
        } else if (value == 'member') {
          await widget.setMemberRole(
            conversationId: widget.conversation.id,
            userId: member.id,
            role: MemberRole.member,
          );
          await _load();
        }
      },
      itemBuilder: (context) => [
        if (canPromote && member.role == MemberRole.member)
          const PopupMenuItem(value: 'admin', child: Text('Promote to admin')),
        if (canPromote && member.role == MemberRole.admin)
          const PopupMenuItem(value: 'member', child: Text('Demote to member')),
        if (canRemove)
          const PopupMenuItem(value: 'remove', child: Text('Remove')),
      ],
    );
  }
}
