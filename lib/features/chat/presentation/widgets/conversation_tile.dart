import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/presentation/formatters/chat_time_format.dart';
import 'package:seyra/features/chat/presentation/widgets/conversation_avatar.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = conversation.unreadCount > 0;

    return ListTile(
      key: Key('conversation_tile_${conversation.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ConversationAvatar(conversation: conversation),
      title: Row(
        children: [
          if (conversation.isPinned) ...[
            Icon(Icons.push_pin, size: 14, color: AppColors.hintOf(context)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatConversationTime(conversation.lastMessageAt),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: unread ? AppColors.accentOf(context) : AppColors.hintOf(context),
              fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                conversation.lastMessagePreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: unread
                      ? AppColors.textOf(context)
                      : AppColors.hintOf(context),
                  fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (conversation.isMuted)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.volume_off_outlined,
                  size: 16,
                  color: AppColors.hintOf(context),
                ),
              ),
            if (unread)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentOf(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    conversation.unreadCount > 9
                        ? '9+'
                        : '${conversation.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}
