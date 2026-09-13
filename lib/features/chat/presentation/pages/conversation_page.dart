import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seyra/app/router/app_routes.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/domain/usecases/clear_conversation_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/delete_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/mark_conversation_read_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/react_to_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/retry_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/set_active_conversation_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/set_conversation_muted_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_conversations_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_messages_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_peer_typing_use_case.dart';
import 'package:seyra/features/chat/presentation/formatters/chat_time_format.dart';
import 'package:seyra/features/chat/presentation/widgets/conversation_avatar.dart';
import 'package:seyra/features/chat/presentation/widgets/message_action_menu.dart';
import 'package:seyra/features/chat/presentation/widgets/message_bubble.dart';
import 'package:seyra/features/chat/presentation/widgets/message_composer.dart';
import 'package:seyra/features/chat/data/crypto/attachment_aead.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/chat/presentation/pages/media_gallery_page.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversationId,
    required this.watchConversations,
    required this.watchMessages,
    required this.watchPeerTyping,
    required this.sendMessage,
    required this.retryMessage,
    required this.deleteMessage,
    required this.reactToMessage,
    required this.markConversationRead,
    required this.clearConversation,
    required this.setMuted,
    required this.setActiveConversation,
    required this.currentUserId,
    this.resolveCurrentUserId,
    this.social,
    this.onOpenDetails,
  });

  final String conversationId;
  final WatchConversationsUseCase watchConversations;
  final WatchMessagesUseCase watchMessages;
  final WatchPeerTypingUseCase watchPeerTyping;
  final SendMessageUseCase sendMessage;
  final RetryMessageUseCase retryMessage;
  final DeleteMessageUseCase deleteMessage;
  final ReactToMessageUseCase reactToMessage;
  final MarkConversationReadUseCase markConversationRead;
  final ClearConversationUseCase clearConversation;
  final SetConversationMutedUseCase setMuted;
  final SetActiveConversationUseCase setActiveConversation;
  final String currentUserId;
  final String Function()? resolveCurrentUserId;
  final ChatSocialRepository? social;
  final ValueChanged<Conversation>? onOpenDetails;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  String get _viewerId => widget.resolveCurrentUserId?.call() ?? widget.currentUserId;
  final _composer = TextEditingController();
  bool _hasText = false;
  ChatMessage? _replyTo;
  late final Stream<List<Conversation>> _conversations;
  late final Stream<List<ChatMessage>> _messages;
  late final Stream<bool> _typing;
  Timer? _draftTimer;
  Timer? _typingIdle;
  double? _uploadProgress;
  Conversation? _cachedConversation;
  DateTime? _peerLastSeen;
  String? _presencePeerId;
  UploadCancelToken? _uploadCancel;
  _PendingUpload? _failedUpload;
  var _selectedIds = <String>{};
  var _sending = false;
  var _cachedMessages = const <ChatMessage>[];

  static const _emojis = ['😀', '😂', '😍', '👍', '🔥', '🎉', '💙', '🙏'];

  @override
  void initState() {
    super.initState();
    _conversations = widget.watchConversations();
    _messages = widget.watchMessages(widget.conversationId);
    _typing = widget.watchPeerTyping(widget.conversationId);
    widget.setActiveConversation(widget.conversationId);
    widget.markConversationRead(widget.conversationId);
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _typingIdle?.cancel();
    widget.social?.sendRealtime({
      'type': 'typing',
      'payload': {
        'conversation_id': widget.conversationId,
        'typing': false,
      },
    });
    widget.setActiveConversation(null);
    _uploadCancel?.cancel();
    _composer.dispose();
    super.dispose();
  }

  void _maybeLoadPresence(Conversation? conversation) {
    if (conversation == null ||
        conversation.kind != ConversationKind.direct ||
        widget.social == null) {
      return;
    }
    final peerId = conversation.peerId;
    if (peerId.isEmpty || peerId == _presencePeerId) {
      return;
    }
    _presencePeerId = peerId;
    unawaited(() async {
      final result = await widget.social!.peerLastSeen(peerId);
      if (!mounted) {
        return;
      }
      if (result is Success<DateTime?>) {
        setState(() => _peerLastSeen = result.value);
      }
    }());
  }

  Future<void> _openAttachment(ChatMessage message) async {
    final social = widget.social;
    final attachmentId = message.attachmentId;
    if (social == null || attachmentId == null || attachmentId.isEmpty) {
      return;
    }
    final downloaded = await social.downloadAttachment(attachmentId);
    if (!mounted) {
      return;
    }
    if (downloaded is! Success<List<int>> || downloaded.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not download file')),
      );
      return;
    }
    var bytes = downloaded.value;
    if (message.e2e) {
      final key = message.fileKey;
      final nonce = message.fileNonce;
      if (key == null || nonce == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decrypt file')),
        );
        return;
      }
      try {
        bytes = await AttachmentAead.decrypt(
          key: key,
          nonce: nonce,
          bytes: bytes,
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decrypt file')),
        );
        return;
      }
    }
    if (!mounted) {
      return;
    }
    final mime = message.contentType ?? '';
    if (mime.startsWith('image/')) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            child: Image.memory(Uint8List.fromList(bytes)),
          );
        },
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloaded ${message.body} (${bytes.length} bytes)'),
      ),
    );
  }

  Future<void> _retryUpload() async {
    final pending = _failedUpload;
    if (pending == null) {
      return;
    }
    setState(() => _failedUpload = null);
    await _uploadAndSend(
      bytes: pending.bytes,
      filename: pending.filename,
      contentType: pending.contentType,
    );
  }

  Future<void> _restoreDraft() async {
    final social = widget.social;
    if (social == null) {
      return;
    }
    final result = await social.getDraft(widget.conversationId);
    if (!mounted || _composer.text.isNotEmpty) {
      return;
    }
    if (result is Success<String> && result.value.isNotEmpty) {
      var text = result.value;
      String? replyId;
      try {
        final decoded = jsonDecode(result.value);
        if (decoded is Map<String, dynamic> && decoded['v'] == 1) {
          text = decoded['body'] as String? ?? '';
          replyId = decoded['reply_to_id'] as String?;
        }
      } catch (_) {}
      _composer.text = text;
      setState(() => _hasText = text.trim().isNotEmpty);
      if (replyId != null && replyId.isNotEmpty) {
        final restoredReplyId = replyId;
        setState(() {
          _replyTo = ChatMessage(
            id: restoredReplyId,
            conversationId: widget.conversationId,
            senderId: '',
            body: 'Reply',
            sentAt: DateTime.now(),
            delivery: MessageDelivery.sent,
          );
        });
      }
    }
  }

  void _scheduleDraftSave(String value) {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistDraft(value));
    });
  }

  Future<void> _persistDraft(String body) async {
    final social = widget.social;
    if (social == null) {
      return;
    }
    await social.saveDraft(
      conversationId: widget.conversationId,
      body: jsonEncode({
        'v': 1,
        'body': body,
        'reply_to_id': _replyTo?.id ?? '',
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Conversation>>(
      stream: _conversations,
      builder: (context, conversationSnapshot) {
        Conversation? conversation;
        for (final item in conversationSnapshot.data ?? const <Conversation>[]) {
          if (item.id == widget.conversationId) {
            conversation = item;
            break;
          }
        }
        _cachedConversation = conversation;
        _maybeLoadPresence(conversation);

        return StreamBuilder<List<ChatMessage>>(
          stream: _messages,
          builder: (context, messageSnapshot) {
            _cachedMessages = messageSnapshot.data ?? const [];
            return StreamBuilder<bool>(
              stream: _typing,
              builder: (context, typingSnapshot) {
                final typing = typingSnapshot.data ?? false;
                return PopScope(
                  canPop: _selectedIds.isEmpty,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) {
                      _clearSelection();
                    }
                  },
                  child: Scaffold(
                  backgroundColor: AppColors.scaffoldOf(context),
                  appBar: _selectedIds.isNotEmpty
                      ? _selectionBar()
                      : _appBar(conversation, typing),
                  body: Column(
                    children: [
                      if (_uploadProgress != null)
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _uploadProgress,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cancel upload',
                              onPressed: () {
                                _uploadCancel?.cancel();
                                setState(() => _uploadProgress = null);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      if (_failedUpload != null)
                        Material(
                          color: AppColors.dangerFillOf(context),
                          child: ListTile(
                            dense: true,
                            title: const Text('Upload failed'),
                            trailing: TextButton(
                              onPressed: _retryUpload,
                              child: const Text('Retry'),
                            ),
                          ),
                        ),
                      Expanded(
                        child: _MessageHistory(
                          messages: _cachedMessages,
                          currentUserId: _viewerId,
                          typing: typing,
                          selectedIds: _selectedIds,
                          onTap: _onMessageTap,
                          onLongPress: _openMessageActions,
                          onRetry: _retry,
                          onOpenAttachment: _openAttachment,
                        ),
                      ),
                      if (_selectedIds.isEmpty)
                        MessageComposer(
                        controller: _composer,
                        hasText: _hasText,
                        sending: _sending,
                        replyTo: _replyTo,
                        onChanged: (value) {
                          setState(() => _hasText = value.trim().isNotEmpty);
                          _scheduleDraftSave(value);
                          _onTypingChanged(value);
                        },
                        onSend: _send,
                        onAttach: _showAttachments,
                        onEmoji: _showEmojis,
                        onMic: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Voice notes are not in this build',
                              ),
                            ),
                          );
                        },
                        onCancelReply: () => setState(() => _replyTo = null),
                      )
                      else
                        _deleteSelectionFooter(),
                    ],
                  ),
                ),
                );
              },
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _selectionBar() {
    final count = _selectedIds.length;
    return AppBar(
      leading: IconButton(
        tooltip: 'Close',
        onPressed: _clearSelection,
        icon: const Icon(Icons.close),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delete messages',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          Text(
            count == 1
                ? '1 message selected'
                : '$count messages selected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.hintOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteSelectionFooter() {
    final count = _selectedIds.length;
    final accent = AppColors.accentOf(context);
    return Material(
      color: AppColors.scaffoldOf(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: _clearSelection,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('selection_footer_delete'),
                onPressed: () => unawaited(_deleteSelected()),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: Text('Delete ($count)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearSelection() {
    setState(() => _selectedIds = {});
  }

  void _onMessageTap(ChatMessage message) {
    if (_selectedIds.isEmpty) {
      return;
    }
    setState(() {
      final next = {..._selectedIds};
      if (!next.add(message.id)) {
        next.remove(message.id);
      }
      _selectedIds = next;
    });
  }

  ChatMessage? _messageById(String id) {
    for (final item in _cachedMessages) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openMessageActions(ChatMessage message, Offset anchor) async {
    if (_selectedIds.isNotEmpty) {
      _onMessageTap(message);
      return;
    }
    setState(() => _selectedIds = {message.id});
    final mine = message.isFrom(_viewerId);
    var keepSelection = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return MessageActionPopup(
          anchor: anchor,
          canDelete: mine,
          onReact: (emoji) {
            keepSelection = false;
            Navigator.pop(context);
            widget.reactToMessage(
              conversationId: widget.conversationId,
              messageId: message.id,
              emoji: emoji,
            );
          },
          onReply: () {
            keepSelection = false;
            Navigator.pop(context);
            setState(() => _replyTo = message);
          },
          onCopy: () {
            keepSelection = false;
            Navigator.pop(context);
            Clipboard.setData(ClipboardData(text: message.body));
          },
          onPin: () {
            keepSelection = false;
            Navigator.pop(context);
            final social = widget.social;
            if (social == null) {
              _comingSoon('Pins');
              return;
            }
            social.pinMessage(
              conversationId: widget.conversationId,
              messageId: message.id,
            );
          },
          onDelete: () {
            keepSelection = false;
            Navigator.pop(context);
            unawaited(_deleteSelected(ids: {message.id}));
          },
          onMoreEmoji: () {
            Navigator.pop(context);
            keepSelection = false;
            _showMoreReactions(message);
          },
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (!keepSelection) {
      setState(() => _selectedIds = {});
    }
  }

  void _showMoreReactions(ChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF252A36),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              children: [
                for (final emoji in _emojis)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.reactToMessage(
                        conversationId: widget.conversationId,
                        messageId: message.id,
                        emoji: emoji,
                      );
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSelected({Set<String>? ids}) async {
    final target = ids ?? _selectedIds;
    final deletable = target.where((id) {
      final message = _messageById(id);
      return message != null && message.isFrom(_viewerId);
    }).toList();
    if (deletable.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only delete your own messages')),
        );
      }
      return;
    }
    final confirmed = await showDeleteMessagesDialog(
      context,
      count: deletable.length,
    );
    if (!confirmed || !mounted) {
      return;
    }
    for (final id in deletable) {
      final result = await widget.deleteMessage(
        conversationId: widget.conversationId,
        messageId: id,
      );
      if (!mounted) {
        return;
      }
      if (result is FailureResult<void>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failure.message)),
        );
        return;
      }
    }
    _clearSelection();
  }

  PreferredSizeWidget _appBar(Conversation? conversation, bool typing) {
    final title = conversation?.title ?? 'Seyra';
    final status = typing
        ? 'typing...'
        : (_peerLastSeen != null
              ? 'last seen ${formatMessageTime(_peerLastSeen!.toLocal())}'
              : (conversation?.statusText.isNotEmpty == true
                    ? conversation!.statusText
                    : ''));

    return AppBar(
      titleSpacing: 0,
      title: conversation == null
          ? Text(title)
          : InkWell(
              onTap: widget.onOpenDetails == null
                  ? null
                  : () => widget.onOpenDetails!(conversation),
              child: Row(
              children: [
                ConversationAvatar(conversation: conversation, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (status.isNotEmpty)
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: typing
                                ? AppColors.accentOf(context)
                                : AppColors.hintOf(context),
                            fontWeight: typing
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ),
      actions: [
        IconButton(
          tooltip: 'Voice call',
          onPressed: () => _openCall(video: false),
          icon: const Icon(Icons.call_outlined),
        ),
        IconButton(
          tooltip: 'Video call',
          onPressed: () => _openCall(video: true),
          icon: const Icon(Icons.videocam_outlined),
        ),
        PopupMenuButton<String>(
          key: const Key('conversation_more_button'),
          onSelected: (value) {
            if (value == 'mute' && conversation != null) {
              widget.setMuted(
                conversationId: conversation.id,
                muted: !conversation.isMuted,
              );
            } else if (value == 'search') {
              Navigator.of(context).pushNamed(AppRoutes.globalSearch);
            } else if (value == 'gallery') {
              final social = widget.social;
              if (social != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MediaGalleryPage(
                      conversationId: widget.conversationId,
                      social: social,
                    ),
                  ),
                );
              }
            } else if (value == 'clear') {
              widget.clearConversation(widget.conversationId);
            } else if (value == 'admin' && conversation != null) {
              Navigator.of(context).pushNamed(
                AppRoutes.roomAdmin,
                arguments: conversation,
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'mute',
              child: Text(conversation?.isMuted == true ? 'Unmute' : 'Mute'),
            ),
            const PopupMenuItem(value: 'search', child: Text('Search')),
            const PopupMenuItem(value: 'gallery', child: Text('Media')),
            if (conversation?.kind == ConversationKind.group ||
                conversation?.kind == ConversationKind.channel)
              const PopupMenuItem(
                value: 'admin',
                child: Text('Administrators'),
              ),
            const PopupMenuItem(value: 'clear', child: Text('Clear history')),
          ],
        ),
      ],
    );
  }

  void _onTypingChanged(String value) {
    final social = widget.social;
    if (social == null) {
      return;
    }
    social.sendRealtime({
      'type': 'typing',
      'payload': {
        'conversation_id': widget.conversationId,
        'typing': value.trim().isNotEmpty,
      },
    });
    _typingIdle?.cancel();
    if (value.trim().isNotEmpty) {
      _typingIdle = Timer(const Duration(seconds: 3), () {
        social.sendRealtime({
          'type': 'typing',
          'payload': {
            'conversation_id': widget.conversationId,
            'typing': false,
          },
        });
      });
    }
  }

  Future<void> _send() async {
    if (_sending) {
      return;
    }
    final body = _composer.text;
    if (body.trim().isEmpty) {
      return;
    }
    final replyToId = _replyTo?.id;
    _sending = true;
    setState(() {
      _hasText = false;
      _replyTo = null;
    });
    _composer.clear();
    unawaited(_persistDraft(''));
    final result = await widget.sendMessage(
      conversationId: widget.conversationId,
      body: body,
      replyToId: replyToId,
    );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (result is FailureResult<ChatMessage>) {
      if (_composer.text.isEmpty) {
        _composer.text = body;
        setState(() => _hasText = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure.message)),
      );
    }
  }

  Future<void> _retry(ChatMessage message) async {
    final result = await widget.retryMessage(
      conversationId: widget.conversationId,
      messageId: message.id,
    );
    if (!mounted) {
      return;
    }
    if (result is FailureResult<ChatMessage>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure.message)),
      );
    }
  }


  void _showAttachments() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Photo'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_pickImage());
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('File'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_pickFile());
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Location'),
                subtitle: const Text('Not available in this build'),
                enabled: false,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEmojis() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: FutureBuilder<Result<List<StickerItem>>>(
            future: widget.social?.listStickers(),
            builder: (context, snapshot) {
              final stickers = switch (snapshot.data) {
                Success<List<StickerItem>>(:final value) => value,
                _ => const <StickerItem>[],
              };
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stickers', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final sticker in stickers)
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              final direct =
                                  _cachedConversation?.kind == ConversationKind.direct;
                              unawaited(
                                widget.sendMessage(
                                  conversationId: widget.conversationId,
                                  body: direct
                                      ? jsonEncode({
                                          'v': 1,
                                          'kind': 'sticker',
                                          'id': sticker.id,
                                          'emoji': sticker.emoji,
                                        })
                                      : sticker.emoji,
                                ),
                              );
                            },
                            child: Text(sticker.emoji, style: const TextStyle(fontSize: 32)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Emoji', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final emoji in _emojis)
                          GestureDetector(
                            onTap: () {
                              _composer.text += emoji;
                              _composer.selection = TextSelection.collapsed(
                                offset: _composer.text.length,
                              );
                              setState(() => _hasText = _composer.text.trim().isNotEmpty);
                              Navigator.pop(context);
                            },
                            child: Text(emoji, style: const TextStyle(fontSize: 28)),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openCall({required bool video}) async {
    if (widget.social == null) {
      _comingSoon(video ? 'Video calls' : 'Voice calls');
      return;
    }
    final peerId = _cachedConversation?.peerId ?? '';
    if (peerId.isEmpty || peerId == _viewerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calls need the other person in this chat')),
      );
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.call,
      arguments: {
        'conversationId': widget.conversationId,
        'video': video,
        'outgoing': true,
        'title': _cachedConversation?.title ?? '',
        'peerId': _cachedConversation?.peerId ?? '',
        'initials': _cachedConversation?.initials ?? '',
      },
    );
  }

  Future<void> _pickImage() async {
    final social = widget.social;
    if (social == null) {
      _comingSoon('Photo attachments');
      return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    final bytes = await picked.readAsBytes();
    await _uploadAndSend(
      bytes: bytes,
      filename: picked.name,
      contentType: 'image/jpeg',
    );
  }

  Future<void> _pickFile() async {
    final social = widget.social;
    if (social == null) {
      _comingSoon('File attachments');
      return;
    }
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) {
      return;
    }
    await _uploadAndSend(
      bytes: file!.bytes!,
      filename: file.name,
      contentType: file.extension == 'pdf' ? 'application/pdf' : 'application/octet-stream',
    );
  }

  Future<void> _uploadAndSend({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final social = widget.social;
    if (social == null) {
      return;
    }
    setState(() {
      _uploadProgress = 0;
      _failedUpload = null;
    });
    final direct = _cachedConversation?.kind == ConversationKind.direct;
    var uploadBytes = bytes;
    var uploadName = filename;
    var uploadType = contentType;
    var e2eUpload = false;
    String sendBody = filename;
    if (direct) {
      try {
        final sealed = await AttachmentAead.encrypt(bytes);
        uploadBytes = sealed.bytes;
        uploadName = 'encrypted.bin';
        uploadType = 'application/octet-stream';
        e2eUpload = true;
        sendBody = jsonEncode({
          'v': 1,
          'kind': 'file',
          'k': base64Encode(sealed.key),
          'n': base64Encode(sealed.nonce),
          'name': filename,
          'mime': contentType,
          'size': bytes.length,
        });
      } catch (_) {
        e2eUpload = false;
        sendBody = filename;
        uploadBytes = bytes;
        uploadName = filename;
        uploadType = contentType;
      }
    }
    final token = UploadCancelToken();
    _uploadCancel = token;
    final uploaded = await social.uploadAttachment(
      conversationId: widget.conversationId,
      bytes: uploadBytes,
      filename: uploadName,
      contentType: uploadType,
      e2e: e2eUpload,
      cancelToken: token,
      onProgress: (sent, total) {
        if (!mounted || total <= 0) {
          return;
        }
        setState(() => _uploadProgress = sent / total);
      },
    );
    _uploadCancel = null;
    if (!mounted) {
      return;
    }
    setState(() => _uploadProgress = null);
    if (token.cancelled) {
      return;
    }
    if (uploaded is! Success<String>) {
      setState(() {
        _failedUpload = _PendingUpload(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
      });
      if (uploaded is FailureResult<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploaded.failure.message)),
        );
      }
      return;
    }
    if (e2eUpload) {
      sendBody = jsonEncode({
        ...jsonDecode(sendBody) as Map<String, dynamic>,
        'att': uploaded.value,
      });
    }
    final sent = await widget.sendMessage(
      conversationId: widget.conversationId,
      body: sendBody,
      attachmentId: uploaded.value,
    );
    if (!mounted) {
      return;
    }
    if (sent is FailureResult<ChatMessage>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sent.failure.message)),
      );
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not available without the chat backend')),
    );
  }
}

class _PendingUpload {
  const _PendingUpload({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String contentType;
}

class _MessageHistory extends StatelessWidget {
  const _MessageHistory({
    required this.messages,
    required this.currentUserId,
    required this.typing,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
    required this.onRetry,
    required this.onOpenAttachment,
  });

  final List<ChatMessage> messages;
  final String currentUserId;
  final bool typing;
  final Set<String> selectedIds;
  final ValueChanged<ChatMessage> onTap;
  final void Function(ChatMessage message, Offset anchor) onLongPress;
  final ValueChanged<ChatMessage> onRetry;
  final ValueChanged<ChatMessage> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final message in messages) {
      if (lastDay == null || !isSameDay(lastDay, message.sentAt)) {
        rows.add(
          DateSeparatorChip(label: formatDateSeparator(message.sentAt)),
        );
        lastDay = message.sentAt;
      }
      rows.add(
        MessageBubble(
          message: message,
          currentUserId: currentUserId,
          selected: selectedIds.contains(message.id),
          selecting: selectedIds.isNotEmpty,
          onTap: () => onTap(message),
          onLongPress: (anchor) => onLongPress(message, anchor),
          onRetry: message.delivery == MessageDelivery.failed
              ? () => onRetry(message)
              : null,
          onOpenAttachment:
              message.attachmentId != null && message.attachmentId!.isNotEmpty
              ? () => onOpenAttachment(message)
              : null,
        ),
      );
    }
    if (typing) {
      rows.add(const TypingIndicatorBubble());
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[rows.length - 1 - index],
    );
  }
}
