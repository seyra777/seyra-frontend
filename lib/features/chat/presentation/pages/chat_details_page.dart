import 'package:flutter/material.dart';
import 'package:seyra/app/router/app_routes.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/room_member.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';
import 'package:seyra/features/chat/domain/usecases/room_member_use_cases.dart';
import 'package:seyra/features/chat/presentation/pages/media_gallery_page.dart';
import 'package:seyra/features/chat/presentation/widgets/conversation_avatar.dart';
import 'package:seyra/features/profile/presentation/widgets/settings_section.dart';

class ChatDetailsPage extends StatefulWidget {
  const ChatDetailsPage({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.listMembers,
    required this.addMembers,
    required this.removeMember,
    required this.setMemberRole,
    required this.leaveConversation,
    required this.onToggleMute,
    required this.onClearLocal,
    required this.onLeft,
    this.social,
  });

  final Conversation conversation;
  final String currentUserId;
  final ListMembersUseCase listMembers;
  final AddMembersUseCase addMembers;
  final RemoveMemberUseCase removeMember;
  final SetMemberRoleUseCase setMemberRole;
  final LeaveConversationUseCase leaveConversation;
  final ValueChanged<bool> onToggleMute;
  final VoidCallback onClearLocal;
  final VoidCallback onLeft;
  final ChatSocialRepository? social;

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  var _loadingMembers = false;
  String? _memberError;
  List<RoomMember> _members = const [];

  bool get _isRoom =>
      widget.conversation.kind == ConversationKind.group ||
      widget.conversation.kind == ConversationKind.channel;

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

  @override
  void initState() {
    super.initState();
    if (_isRoom) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loadingMembers = true;
      _memberError = null;
    });
    final result = await widget.listMembers(widget.conversation.id);
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _loadingMembers = false;
          _memberError = failure.message;
        });
      case Success(:final value):
        setState(() {
          _loadingMembers = false;
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
            key: const Key('add_member_username'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      case Success(:final value):
        setState(() => _members = value);
    }
  }

  Future<void> _leave() async {
    final result = await widget.leaveConversation(widget.conversation.id);
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      case Success():
        widget.onLeft();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(
          widget.conversation.kind == ConversationKind.group
              ? 'Group details'
              : widget.conversation.kind == ConversationKind.channel
              ? 'Channel details'
              : 'Chat details',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),
          Center(child: ConversationAvatar(conversation: widget.conversation, size: 88)),
          const SizedBox(height: 12),
          Text(
            widget.conversation.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              color: AppColors.textOf(context),
            ),
          ),
          if (widget.conversation.statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.conversation.statusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (_isRoom) _membersSection(context),
          if (_isRoom)
            SettingsSection(
              title: 'Administration',
              children: [
                SettingsTile(
                  key: const Key('open_administrators'),
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Administrators',
                  subtitle: _canManage
                      ? 'Roles, members, and invite link'
                      : 'View owner and admins',
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.roomAdmin,
                      arguments: widget.conversation,
                    );
                  },
                ),
              ],
            ),
          SettingsSection(
            title: 'Chat',
            children: [
              if (widget.social != null)
                SettingsTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Media',
                  subtitle: 'Files shared in this chat',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MediaGalleryPage(
                          conversationId: widget.conversation.id,
                          social: widget.social!,
                        ),
                      ),
                    );
                  },
                ),
              SettingsTile(
                icon: Icons.notifications_outlined,
                title: widget.conversation.isMuted ? 'Unmute' : 'Mute notifications',
                subtitle: 'Persisted for this account',
                onTap: () => widget.onToggleMute(!widget.conversation.isMuted),
              ),
              if (widget.social != null && _isRoom && _canManage)
                SettingsTile(
                  icon: Icons.link,
                  title: 'Invite link',
                  subtitle: 'Create a join token',
                  onTap: () async {
                    final result = await widget.social!.createInvite(
                      widget.conversation.id,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    final text = result is Success<String>
                        ? result.value
                        : (result as FailureResult).failure.message;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(text)),
                    );
                  },
                ),
              if (widget.social != null)
                SettingsTile(
                  icon: Icons.archive_outlined,
                  title: 'Archive',
                  onTap: () {
                    widget.social!.setArchived(
                      conversationId: widget.conversation.id,
                      archived: true,
                    );
                  },
                ),
              SettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear local history',
                subtitle: 'Removes messages from this device. Server history is kept.',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Clear local history?'),
                        content: const Text(
                          'This only clears the conversation on this device. It does not delete messages on the server.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed == true) {
                    widget.onClearLocal();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _membersSection(BuildContext context) {
    return SettingsSection(
      title: 'Members',
      children: [
        if (_loadingMembers)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_memberError != null)
          ListTile(
            title: Text(_memberError!),
            trailing: TextButton(onPressed: _loadMembers, child: const Text('Retry')),
          )
        else ...[
          if (_canManage)
            ListTile(
              key: const Key('add_group_member'),
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Add member'),
              onTap: _addMember,
            ),
          for (final member in _members)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.mutedOf(context),
                child: Text(
                  member.username.isEmpty ? '?' : member.username[0].toUpperCase(),
                  style: TextStyle(color: AppColors.textOf(context)),
                ),
              ),
              title: Text(member.username),
              subtitle: Text(member.roleLabel),
              trailing: _memberMenu(member),
            ),
          if (_myRole != MemberRole.owner)
            ListTile(
              key: const Key('leave_group'),
              leading: Icon(Icons.exit_to_app, color: AppColors.dangerOf(context)),
              title: Text(
                'Leave group',
                style: TextStyle(color: AppColors.dangerOf(context)),
              ),
              onTap: _leave,
            ),
        ],
      ],
    );
  }

  Widget? _memberMenu(RoomMember member) {
    if (member.id == widget.currentUserId || member.role == MemberRole.owner) {
      return null;
    }
    final canRemove = _myRole == MemberRole.owner ||
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
            await _loadMembers();
          }
        } else if (value == 'admin') {
          await widget.setMemberRole(
            conversationId: widget.conversation.id,
            userId: member.id,
            role: MemberRole.admin,
          );
          await _loadMembers();
        } else if (value == 'member') {
          await widget.setMemberRole(
            conversationId: widget.conversation.id,
            userId: member.id,
            role: MemberRole.member,
          );
          await _loadMembers();
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
