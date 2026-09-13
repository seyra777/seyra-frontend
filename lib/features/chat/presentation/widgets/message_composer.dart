import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.hasText,
    required this.replyTo,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    required this.onEmoji,
    required this.onMic,
    required this.onCancelReply,
    this.sending = false,
  });

  final TextEditingController controller;
  final bool hasText;
  final bool sending;
  final ChatMessage? replyTo;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final VoidCallback onAttach;
  final VoidCallback onEmoji;
  final VoidCallback onMic;
  final VoidCallback onCancelReply;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  var _busy = false;

  Future<void> _handleSend() async {
    if (_busy || widget.sending) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSend();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final sending = _busy || widget.sending;
    return Material(
      color: AppColors.scaffoldOf(context),
      elevation: 8,
      shadowColor: const Color(0x1A000000),
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, 8, 6, 8 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null)
              Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mutedOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: AppColors.accentOf(context), width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 18, color: AppColors.accentOf(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.replyTo!.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: const Key('composer_cancel_reply'),
                      onPressed: widget.onCancelReply,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('composer_attach_button'),
                  tooltip: 'Attach',
                  onPressed: widget.onAttach,
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.mutedOf(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('composer_emoji_button'),
                          tooltip: 'Emoji',
                          onPressed: widget.onEmoji,
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                        Expanded(
                          child: TextField(
                            key: const Key('composer_text_field'),
                            controller: widget.controller,
                            minLines: 1,
                            maxLines: 5,
                            onChanged: widget.onChanged,
                            enabled: !sending,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: widget.hasText
                      ? Material(
                          color: AppColors.accentOf(context),
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: const Key('composer_send_button'),
                            customBorder: const CircleBorder(),
                            onTap: sending ? null : _handleSend,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: sending
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                          ),
                        )
                      : IconButton(
                          key: const Key('composer_mic_button'),
                          tooltip: 'Voice message',
                          onPressed: widget.onMic,
                          icon: const Icon(Icons.mic_none_outlined),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
