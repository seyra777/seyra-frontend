import 'package:flutter/material.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/profile/presentation/widgets/user_avatar.dart';

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.conversation,
    this.size = 48,
  });

  final Conversation conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      const Color(0xFF2F6FED),
      const Color(0xFF3B82F6),
      const Color(0xFF1D4ED8),
      const Color(0xFF0F766E),
      const Color(0xFF4F46E5),
    ];
    final color = colors[conversation.title.hashCode.abs() % colors.length];
    final radius = size / 2;

    if (conversation.kind == ConversationKind.direct &&
        conversation.peerId.isNotEmpty) {
      return UserAvatar(
        userId: conversation.peerId,
        initials: conversation.initials,
        radius: radius,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Icon(
        conversation.kind == ConversationKind.group
            ? Icons.group_outlined
            : Icons.campaign_outlined,
        color: Colors.white,
        size: size * 0.46,
      ),
    );
  }
}
