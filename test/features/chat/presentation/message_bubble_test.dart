import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/theme/app_theme.dart';
import 'package:seyra/features/chat/domain/entities/chat_message.dart';
import 'package:seyra/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('failed messages show a retry action', (tester) async {
    var retried = false;
    final message = ChatMessage(
      id: 'pending_1',
      conversationId: 'cht_1',
      senderId: 'usr_ada',
      body: 'offline',
      sentAt: DateTime.utc(2026, 9, 8, 12),
      delivery: MessageDelivery.failed,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MessageBubble(
            message: message,
            currentUserId: 'usr_ada',
            onLongPress: (_) {},
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('retry_message_pending_1')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('sent messages do not show delivered ticks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: 'msg_1',
              conversationId: 'cht_1',
              senderId: 'usr_ada',
              body: 'hello',
              sentAt: DateTime.utc(2026, 9, 8, 12),
              delivery: MessageDelivery.sent,
            ),
            currentUserId: 'usr_ada',
            onLongPress: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('read messages show double ticks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: 'msg_1',
              conversationId: 'cht_1',
              senderId: 'usr_ada',
              body: 'hello',
              sentAt: DateTime.utc(2026, 9, 8, 12),
              delivery: MessageDelivery.read,
            ),
            currentUserId: 'usr_ada',
            onLongPress: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
