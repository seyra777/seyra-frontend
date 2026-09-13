import 'dart:async';

import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/data/models/conversation_summary_model.dart';
import 'package:seyra/features/chat/domain/entities/user_preview.dart';
import 'package:seyra/features/chat/domain/usecases/search_users_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_direct_chat_use_case.dart';

class NewConversationPage extends StatefulWidget {
  const NewConversationPage({
    super.key,
    required this.searchUsers,
    required this.startDirectChat,
    required this.onOpened,
  });

  final SearchUsersUseCase searchUsers;
  final StartDirectChatUseCase startDirectChat;
  final ValueChanged<String> onOpened;

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  final _username = TextEditingController();
  Timer? _debounce;
  var _loading = false;
  var _opening = false;
  String? _error;
  List<UserPreview>? _results;
  var _hasQueried = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
        _hasQueried = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _hasQueried = true;
    });
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

  Future<void> _open(UserPreview user) async {
    if (_opening) {
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    final result = await widget.startDirectChat(user.username);
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _opening = false;
          _error = failure.message;
        });
      case Success(:final value):
        setState(() {
          _opening = false;
        });
        widget.onOpened(value.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('New chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('new_chat_username_field'),
              controller: _username,
              enabled: !_opening,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              decoration: AppColors.searchField(
                context,
                hint: 'Search username',
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                _error!,
                key: const Key('new_chat_error_message'),
                style: TextStyle(color: AppColors.dangerOf(context)),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_opening) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('new_chat_loading')),
      );
    }
    if (!_hasQueried) {
      return const _SearchHint(
        icon: Icons.person_search_outlined,
        title: 'Find someone on Seyra',
        subtitle: 'Search by username to start a private chat.',
      );
    }
    final results = _results ?? const <UserPreview>[];
    if (results.isEmpty) {
      return const _SearchHint(
        key: Key('new_chat_empty_results'),
        icon: Icons.search_off,
        title: 'No users found',
        subtitle: 'Try a different username prefix.',
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user = results[index];
        return ListTile(
          key: Key('new_chat_result_${user.username}'),
          leading: CircleAvatar(
            backgroundColor: AppColors.avatarFillOf(context),
            child: Text(
              chatInitials(user.username),
              style: TextStyle(
                color: AppColors.avatarFgOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(user.username),
          subtitle: Text('@${user.username}'),
          onTap: () => _open(user),
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.hintOf(context)),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
