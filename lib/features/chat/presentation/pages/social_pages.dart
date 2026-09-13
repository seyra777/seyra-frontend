import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';
import 'package:seyra/features/chat/presentation/formatters/chat_time_format.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/app/router/app_routes.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key, required this.social});

  final ChatSocialRepository social;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  var _query = '';
  var _loading = false;
  String? _error;
  GlobalSearchResult _result = const GlobalSearchResult();

  Future<void> _run(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.social.searchGlobal(query);
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
          _result = value;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      backgroundColor: AppColors.scaffoldOf(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                _query = value;
                if (value.trim().length >= 2) {
                  unawaited(_run(value.trim()));
                }
              },
              decoration: AppColors.searchField(
                context,
                hint: 'Users, chats, messages',
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: AppColors.dangerOf(context)),
              ),
            ),
          Expanded(
            child: _query.trim().length < 2
                ? Center(
                    child: Text(
                      'Type at least 2 characters',
                      style: TextStyle(color: AppColors.hintOf(context)),
                    ),
                  )
                : ListView(
                    children: [
                      if (_result.users.isNotEmpty)
                        const ListTile(title: Text('People')),
                      for (final user in _result.users)
                        ListTile(
                          title: Text(user.username),
                          subtitle: Text('@${user.username}'),
                        ),
                      if (_result.conversations.isNotEmpty)
                        const ListTile(title: Text('Chats')),
                      for (final chat in _result.conversations)
                        ListTile(
                          title: Text(chat.title),
                          subtitle: Text(chat.lastMessagePreview),
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.conversation,
                            arguments: chat.id,
                          ),
                        ),
                      if (_result.messages.isNotEmpty)
                        const ListTile(title: Text('Messages')),
                      for (final message in _result.messages)
                        ListTile(
                          title: Text(message.body),
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.conversation,
                            arguments: message.conversationId,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class DiscoverChannelsPage extends StatefulWidget {
  const DiscoverChannelsPage({super.key, required this.social});

  final ChatSocialRepository social;

  @override
  State<DiscoverChannelsPage> createState() => _DiscoverChannelsPageState();
}

class _DiscoverChannelsPageState extends State<DiscoverChannelsPage> {
  var _loading = true;
  String? _error;
  var _items = <Conversation>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.social.discoverChannels(query);
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
          _items = value;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover channels')),
      backgroundColor: AppColors.scaffoldOf(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => unawaited(_load(value.trim())),
              decoration: AppColors.searchField(
                context,
                hint: 'Search public channels',
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            TextButton(onPressed: () => _load(''), child: Text('Retry: $_error')),
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Text(
                      'No public channels',
                      style: TextStyle(color: AppColors.hintOf(context)),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final chat = _items[index];
                      return ListTile(
                        title: Text(chat.title),
                        subtitle: Text(chat.statusText),
                        trailing: TextButton(
                          onPressed: () async {
                            final joined = await widget.social.joinChannel(chat.id);
                            if (joined is Success && context.mounted) {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.conversation,
                                arguments: chat.id,
                              );
                            }
                          },
                          child: const Text('Join'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PrivacyControlsPage extends StatefulWidget {
  const PrivacyControlsPage({super.key, required this.social});

  final ChatSocialRepository social;

  @override
  State<PrivacyControlsPage> createState() => _PrivacyControlsPageState();
}

class _PrivacyControlsPageState extends State<PrivacyControlsPage> {
  PrivacySettings? _settings;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final result = await widget.social.getPrivacy();
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() => _error = failure.message);
      case Success(:final value):
        setState(() => _settings = value);
    }
  }

  Future<void> _save(PrivacySettings next) async {
    setState(() => _settings = next);
    await widget.social.putPrivacy(next);
    await AppDependencies.profileRepository.reloadRemote();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('Privacy')),
      body: settings == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _load, child: Text(_error!)),
            )
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Last seen visible'),
                  subtitle: const Text(
                    'When off, people in a 1-to-1 chat will not see your last-seen time. Not a live online indicator.',
                  ),
                  value: settings.lastSeenVisible,
                  onChanged: (value) =>
                      _save(settings.copyWith(lastSeenVisible: value)),
                ),
                SwitchListTile(
                  title: const Text('Read receipts'),
                  subtitle: const Text(
                    'When off, others will not see when you last read a 1-to-1 chat. Your own unread counts still update.',
                  ),
                  value: settings.readReceipts,
                  onChanged: (value) =>
                      _save(settings.copyWith(readReceipts: value)),
                ),
                SwitchListTile(
                  title: const Text('Typing indicators'),
                  subtitle: const Text(
                    'When off, the server will not broadcast that you are typing.',
                  ),
                  value: settings.typingVisible,
                  onChanged: (value) =>
                      _save(settings.copyWith(typingVisible: value)),
                ),
                SwitchListTile(
                  title: const Text('Profile visible in search'),
                  value: settings.profileVisible,
                  onChanged: (value) =>
                      _save(settings.copyWith(profileVisible: value)),
                ),
                SwitchListTile(
                  title: const Text('Notification previews'),
                  value: settings.notificationPreview,
                  onChanged: (value) =>
                      _save(settings.copyWith(notificationPreview: value)),
                ),
                SwitchListTile(
                  title: const Text('Profile photo visible'),
                  subtitle: const Text(
                    'When off, other people cannot download your avatar. You can always see your own.',
                  ),
                  value: settings.photoVisible,
                  onChanged: (value) =>
                      _save(settings.copyWith(photoVisible: value)),
                ),
              ],
            ),
    );
  }
}

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.social});

  final ChatSocialRepository social;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  var _items = const <AuthDeviceSession>[];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final result = await widget.social.listSessions();
    if (!mounted) {
      return;
    }
    if (result is Success<List<AuthDeviceSession>>) {
      setState(() {
        _items = result.value.where((session) => !session.revoked).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('Devices & sessions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('No active sessions'))
          : ListView(
              children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Each row is a signed-in device. Revoking signs that device out. Expired or already revoked sessions are not listed. Tokens are never shown.',
                      style: TextStyle(color: AppColors.hintOf(context)),
                    ),
                  ),
                for (final session in _items)
                  ListTile(
                    title: Text(
                      session.current
                          ? 'This device'
                          : describeDevice(session.userAgent),
                    ),
                    subtitle: Text(
                      [
                        if (session.current) 'Current'
                        else 'Active',
                        if (session.createdAt != null)
                          'signed in ${formatShortDateTime(session.createdAt!)}',
                        'expires ${formatShortDateTime(session.expiresAt)}',
                      ].join(' · '),
                    ),
                    trailing: session.current
                        ? null
                        : IconButton(
                            tooltip: 'Revoke this session',
                            icon: const Icon(Icons.logout),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Revoke session?'),
                                    content: const Text(
                                      'That device will be signed out immediately.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Revoke'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (ok == true) {
                                await widget.social.revokeSession(session.id);
                                await _load();
                              }
                            },
                          ),
                  ),
                if (_items.any((s) => !s.current))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Sign out other sessions?'),
                              content: const Text(
                                'Every other device will be signed out. This device stays signed in.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Revoke others'),
                                ),
                              ],
                            );
                          },
                        );
                        if (ok == true) {
                          await widget.social.revokeOtherSessions();
                          await _load();
                        }
                      },
                      child: const Text('Revoke other sessions'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class BotsPage extends StatefulWidget {
  const BotsPage({super.key, required this.social});

  final ChatSocialRepository social;

  @override
  State<BotsPage> createState() => _BotsPageState();
}

class _BotsPageState extends State<BotsPage> {
  var _bots = const <BotAccount>[];
  final _username = TextEditingController(text: 'echo_bot');
  final _grantChat = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _username.dispose();
    _grantChat.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await widget.social.listBots();
    if (result is Success<List<BotAccount>> && mounted) {
      setState(() => _bots = result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(title: const Text('Bots')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'A bot is a special account you own. Create one, copy the token (shown once), then grant it into a group or channel you admin. The token is hashed on the server and never listed again. In a granted room the bot can answer /ping, /help, and /whoami when it has can_send. Permissions (read, send, manage messages, manage members) are enforced on the server.',
            style: TextStyle(color: AppColors.hintOf(context)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Bot username'),
          ),
          const SizedBox(height: 8),
          Text(
            'Commands in a granted room: /ping, /help, /whoami. Token is shown once.',
            style: TextStyle(color: AppColors.hintOf(context)),
          ),
          FilledButton(
            onPressed: () async {
              final created = await widget.social.createBot(_username.text.trim());
              if (created is Success<BotAccount> && context.mounted) {
                final token = created.value.token ?? '';
                await Clipboard.setData(ClipboardData(text: token));
                if (!context.mounted) {
                  return;
                }
                await showDialog<void>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Bot token (once)'),
                      content: SelectableText(
                        token.isEmpty
                            ? 'No token returned'
                            : token,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('I stored it'),
                        ),
                      ],
                    );
                  },
                );
                await _load();
              }
            },
            child: const Text('Create bot'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _grantChat,
            decoration: const InputDecoration(
              labelText: 'Group or channel ID',
              helperText: 'Add the bot to a room you admin, then send /ping',
            ),
          ),
          if (_bots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('No bots yet. Create one to get a token (shown once).'),
            ),
          for (final bot in _bots)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.smart_toy_outlined)),
              title: Text(bot.username),
              subtitle: const Text('Bot account · token is not stored in the app'),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () => _grant(bot),
                    child: const Text('Permissions'),
                  ),
                  IconButton(
                    onPressed: () async {
                      await widget.social.deleteBot(bot.id);
                      await _load();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _grant(BotAccount bot) async {
    var canRead = true;
    var canSend = true;
    var canManageMessages = false;
    var canManageMembers = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Grant ${bot.username}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Room: ${_grantChat.text.trim()}'),
                  CheckboxListTile(
                    title: const Text('can_read'),
                    value: canRead,
                    onChanged: (value) => setLocal(() => canRead = value ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('can_send'),
                    value: canSend,
                    onChanged: (value) => setLocal(() => canSend = value ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('can_manage_messages'),
                    value: canManageMessages,
                    onChanged: (value) =>
                        setLocal(() => canManageMessages = value ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('can_manage_members'),
                    value: canManageMembers,
                    onChanged: (value) =>
                        setLocal(() => canManageMembers = value ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Grant'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await widget.social.grantBot(
      botId: bot.id,
      conversationId: _grantChat.text.trim(),
      canRead: canRead,
      canSend: canSend,
      canManageMessages: canManageMessages,
      canManageMembers: canManageMembers,
    );
  }
}

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({
    super.key,
    required this.social,
    required this.currentUserId,
    this.active = true,
    this.embedded = false,
  });

  final ChatSocialRepository social;
  final String currentUserId;
  final bool active;
  final bool embedded;

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  var _items = const <CallRecord>[];
  var _loading = true;
  StreamSubscription<Map<String, dynamic>>? _signals;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _signals = widget.social.watchCallSignals().listen((_) {
      unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant CallHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    unawaited(_signals?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final result = await widget.social.listCalls();
    if (!mounted) {
      return;
    }
    if (result is Success<List<CallRecord>>) {
      setState(() {
        _items = result.value;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteOne(CallRecord call) async {
    await widget.social.deleteCall(call.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.isDark(context)
              ? AppColors.darkSurface
              : null,
          title: const Text('Clear call history?'),
          content: const Text(
            'This removes call records from your account. It does not delete the chats.',
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
    if (ok == true) {
      await widget.social.clearCallHistory();
      await _load();
    }
  }

  String _title(CallRecord call) {
    if (call.peerName.trim().isNotEmpty) {
      return call.peerName.trim();
    }
    return 'Unknown';
  }

  String _subtitle(CallRecord call) {
    final outgoing = call.outgoing || call.callerId == widget.currentUserId;
    final direction = outgoing ? 'Outgoing' : 'Incoming';
    final kind = call.kind == 'video' ? 'video' : 'voice';
    final when = formatConversationTime(call.createdAt);
    final missed = call.state == 'missed' || call.state == 'rejected';
    final status = missed ? 'missed' : call.state;
    final duration = (call.durationSeconds ?? 0) > 0
        ? ' · ${call.durationSeconds}s'
        : '';
    return '$direction $kind · $status$duration · $when';
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No calls yet')),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: widget.embedded ? 96 : 24,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final call = _items[index];
                      final missed =
                          call.state == 'missed' || call.state == 'rejected';
                      final outgoing = call.outgoing ||
                          call.callerId == widget.currentUserId;
                      return Dismissible(
                        key: ValueKey(call.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: const Color(0xFFE53935),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => unawaited(_deleteOne(call)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.avatarFillOf(context),
                            child: Icon(
                              call.kind == 'video'
                                  ? Icons.videocam_outlined
                                  : (outgoing
                                      ? Icons.call_made
                                      : Icons.call_received),
                              color: missed
                                  ? const Color(0xFFE53935)
                                  : AppColors.accentOf(context),
                            ),
                          ),
                          title: Text(
                            _title(call),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: missed
                                  ? const Color(0xFFE53935)
                                  : AppColors.textOf(context),
                            ),
                          ),
                          subtitle: Text(_subtitle(call)),
                          trailing: IconButton(
                            tooltip: 'Call again',
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.call,
                                arguments: {
                                  'conversationId': call.conversationId,
                                  'video': call.kind == 'video',
                                  'outgoing': true,
                                  'title': _title(call),
                                },
                              );
                            },
                            icon: Icon(
                              Icons.call_outlined,
                              color: AppColors.accentOf(context),
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.conversation,
                              arguments: call.conversationId,
                            );
                          },
                        ),
                      );
                    },
                  ),
          );

    final startCall = Positioned(
      left: 24,
      right: 24,
      bottom: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.newChat);
          },
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: AppColors.brandGradientOf(context),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x335D5FEF),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Start a call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(
        color: AppColors.scaffoldOf(context),
        child: Stack(
          children: [
            body,
            if (_items.isNotEmpty || !_loading) startCall,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Calls'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Stack(
        children: [
          body,
          if (_items.isNotEmpty || !_loading) startCall,
        ],
      ),
    );
  }
}
