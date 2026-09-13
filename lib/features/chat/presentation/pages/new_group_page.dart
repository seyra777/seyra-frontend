import 'dart:async';

import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/branding/presentation/widgets/seyra_brand_mark.dart';
import 'package:seyra/features/chat/data/models/conversation_summary_model.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/usecases/search_users_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_channel_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_group_use_case.dart';

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({
    super.key,
    required this.kind,
    required this.searchUsers,
    this.startGroup,
    this.startChannel,
    required this.onOpened,
  });

  final ConversationKind kind;
  final SearchUsersUseCase searchUsers;
  final StartGroupUseCase? startGroup;
  final StartChannelUseCase? startChannel;
  final ValueChanged<String> onOpened;

  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final _title = TextEditingController();
  final _username = TextEditingController();
  Timer? _debounce;
  var _loading = false;
  var _creating = false;
  var _public = false;
  String? _error;
  List<UserPreview>? _results;
  final _selected = <String, UserPreview>{};

  bool get _isChannel => widget.kind == ConversationKind.channel;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _username.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_search(query));
    });
  }

  Future<void> _search(String query) async {
    final result = await widget.searchUsers(query);
    if (!mounted || _username.text.trim() != query) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _loading = false;
          _error = failure.message;
          _results = const [];
        });
      case Success(:final value):
        setState(() {
          _loading = false;
          _error = null;
          _results = value;
        });
    }
  }

  Future<void> _create() async {
    if (_creating) {
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    final usernames = _selected.values.map((user) => user.username).toList();
    final result = _isChannel
        ? await widget.startChannel!(
            title: _title.text,
            usernames: usernames,
            visibility: _public ? 'public' : 'private',
          )
        : await widget.startGroup!(title: _title.text, usernames: usernames);
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _creating = false;
          _error = failure.message;
        });
      case Success(:final value):
        setState(() {
          _creating = false;
        });
        widget.onOpened(value.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(_isChannel ? 'New channel' : 'New group'),
        actions: [
          TextButton(
            key: const Key('create_group_button'),
            onPressed: _creating ? null : _create,
            child: const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isChannel)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Center(child: SeyraAppIcon(size: 112)),
            ),
          if (_isChannel)
            SwitchListTile(
              title: const Text('Public channel'),
              subtitle: const Text('Discoverable. Private channels stay invite-only.'),
              value: _public,
              onChanged: (value) => setState(() => _public = value),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('group_title_field'),
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: AppColors.searchField(
                context,
                hint: _isChannel ? 'Channel name' : 'Group name',
                icon: Icons.edit_outlined,
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final user in _selected.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(user.username),
                        onDeleted: () => setState(() {
                          _selected.remove(user.id);
                        }),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('group_member_search_field'),
              controller: _username,
              onChanged: _onQueryChanged,
              decoration: AppColors.searchField(
                context,
                hint: 'Search people to add',
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _error!,
                key: const Key('new_group_error'),
                style: TextStyle(color: AppColors.dangerOf(context)),
              ),
            ),
          Expanded(
            child: _creating
                ? const Center(child: CircularProgressIndicator())
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : _results == null
                ? Center(
                    child: Text(
                      _isChannel
                          ? 'Optionally invite members. Anyone with the name can join later if public.'
                          : 'Search and select at least one member.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : (_results!.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.builder(
                        itemCount: _results!.length,
                        itemBuilder: (context, index) {
                          final user = _results![index];
                          final selected = _selected.containsKey(user.id);
                          return CheckboxListTile(
                            key: Key('group_result_${user.username}'),
                            value: selected,
                            title: Text(user.username),
                            subtitle: Text('@${user.username}'),
                            secondary: CircleAvatar(
                              backgroundColor: AppColors.avatarFillOf(context),
                              child: Text(
                                chatInitials(user.username),
                                style: TextStyle(
                                  color: AppColors.avatarFgOf(context),
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selected[user.id] = user;
                                } else {
                                  _selected.remove(user.id);
                                }
                              });
                            },
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
