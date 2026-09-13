import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/presentation/formatters/chat_time_format.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.onLongPress,
    this.onTap,
    this.selected = false,
    this.selecting = false,
    this.onRetry,
    this.onOpenAttachment,
  });

  final ChatMessage message;
  final String currentUserId;
  final ValueChanged<Offset> onLongPress;
  final VoidCallback? onTap;
  final bool selected;
  final bool selecting;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final mine = message.isFrom(currentUserId);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: mine ? (selecting ? 48 : 64) : 8,
          right: mine ? 8 : (selecting ? 48 : 64),
          bottom: 8,
        ),
        child: GestureDetector(
          onTap: onTap,
          onLongPressStart: (details) => onLongPress(details.globalPosition),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selecting && !mine) _SelectionMark(selected: selected),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 80,
                ),
                child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  gradient: mine ? AppColors.brandGradientOf(context) : null,
                  color: mine
                      ? null
                      : AppColors.receivedBubbleOf(context),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18),
                  ),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0xAA5D5FEF),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyPreview != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: mine
                              ? Colors.white.withValues(alpha: 0.16)
                              : AppColors.mutedOf(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: mine ? Colors.white : AppColors.accentOf(context),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          message.replyPreview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mine
                                ? Colors.white
                                : AppColors.textOf(context),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    Text(
                      _displayBody(message),
                      style: TextStyle(
                        color: mine ? Colors.white : AppColors.textOf(context),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    if (message.attachmentId != null &&
                        message.attachmentId!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: onOpenAttachment,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              message.e2e
                                  ? Icons.lock_outline
                                  : Icons.attach_file,
                              size: 16,
                              color: mine ? Colors.white : AppColors.accentOf(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              message.e2e ? 'Encrypted file' : 'Attachment',
                              style: TextStyle(
                                color: mine ? Colors.white : AppColors.accentOf(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMessageTime(message.sentAt),
                          style: TextStyle(
                            color: mine
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppColors.hintOf(context),
                            fontSize: 11,
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _deliveryIcon(message.delivery),
                            size: 14,
                            color: message.delivery == MessageDelivery.failed
                                ? const Color(0xFFFFCDD2)
                                : message.delivery == MessageDelivery.read
                                ? const Color(0xFF90CAF9)
                                : Colors.white.withValues(alpha: 0.85),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (mine &&
                  message.delivery == MessageDelivery.failed &&
                  onRetry != null)
                TextButton(
                  key: Key('retry_message_${message.id}'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              if (message.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (final reaction in message.reactions)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: reaction.reactedByMe
                                ? (AppColors.isDark(context)
                                    ? AppColors.darkAccent.withValues(alpha: 0.35)
                                    : AppColors.wave)
                                : AppColors.cardOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Text(
                            '${reaction.emoji} ${reaction.count}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
                ),
              ),
              if (selecting && mine) _SelectionMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }

  static String _displayBody(ChatMessage message) {
    final raw = message.body;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['v'] == 1) {
        if (decoded['kind'] == 'sticker') {
          return decoded['emoji'] as String? ?? raw;
        }
        if (decoded['kind'] == 'file') {
          return decoded['name'] as String? ?? 'File';
        }
      }
    } catch (_) {}
    return raw;
  }

  IconData _deliveryIcon(MessageDelivery delivery) {
    return switch (delivery) {
      MessageDelivery.sending => Icons.schedule,
      MessageDelivery.failed => Icons.error_outline,
      MessageDelivery.sent => Icons.check,
      MessageDelivery.delivered || MessageDelivery.read => Icons.done_all,
    };
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: selected
          ? Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            )
          : Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.hintOf(context).withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
            ),
    );
  }
}

class DateSeparatorChip extends StatelessWidget {
  const DateSeparatorChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.isDark(context)
                ? AppColors.darkSurface
                : Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.hintOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class TypingIndicatorBubble extends StatelessWidget {
  const TypingIndicatorBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: 64, bottom: 8),
        child: _TypingDots(),
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delay: 0),
          SizedBox(width: 4),
          _Dot(delay: 120),
          SizedBox(width: 4),
          _Dot(delay: 240),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});

  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_controller),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.hintOf(context),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
