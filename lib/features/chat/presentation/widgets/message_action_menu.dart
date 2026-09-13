import 'package:flutter/material.dart';

const _menuFill = Color(0xFF252A36);
const _deleteRed = Color(0xFFFF5C5C);

class MessageActionPopup extends StatelessWidget {
  const MessageActionPopup({
    super.key,
    required this.anchor,
    required this.canDelete,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onPin,
    required this.onDelete,
    required this.onMoreEmoji,
  });

  final Offset anchor;
  final bool canDelete;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onMoreEmoji;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final left = (anchor.dx - 148).clamp(12.0, size.width - 300);
    final top = (anchor.dy - 196).clamp(56.0, size.height - 420);
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReactionBar(
                  onReact: onReact,
                  onMore: onMoreEmoji,
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  canDelete: canDelete,
                  onReply: onReply,
                  onCopy: onCopy,
                  onPin: onPin,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({required this.onReact, required this.onMore});

  final ValueChanged<String> onReact;
  final VoidCallback onMore;

  static const _emojis = ['❤️', '👍', '😂', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _menuFill,
      elevation: 12,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in _emojis)
              InkWell(
                onTap: () => onReact(emoji),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.canDelete,
    required this.onReply,
    required this.onCopy,
    required this.onPin,
    required this.onDelete,
  });

  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _menuFill,
      elevation: 16,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(Icons.reply_rounded, 'Reply', onReply),
            _row(Icons.copy_rounded, 'Copy', onCopy),
            _row(Icons.push_pin_outlined, 'Pin', onPin),
            if (canDelete)
              _row(
                Icons.delete_outline,
                'Delete',
                onDelete,
                color: _deleteRed,
                key: const Key('message_action_delete'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white,
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showDeleteMessagesDialog(
  BuildContext context, {
  required int count,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E232E),
        title: Text(
          count == 1 ? 'Delete message?' : 'Delete $count messages?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          count == 1
              ? 'This removes the message for you and the other participant.'
              : 'This removes the selected messages for you and the other participant.',
          style: const TextStyle(color: Color(0xFFB0B6C3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            key: const Key('confirm_delete_message'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: _deleteRed)),
          ),
        ],
      );
    },
  ).then((value) => value == true);
}
