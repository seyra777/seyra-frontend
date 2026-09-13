import 'package:flutter_test/flutter_test.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/features/chat/data/repositories/mock_chat_social_repository.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';

void main() {
  test('mock social privacy persists', () async {
    final repo = MockChatSocialRepository();
    final updated = await repo.putPrivacy(
      const PrivacySettings(profileVisible: false),
    );
    expect(updated, isA<Success<void>>());
    final loaded = await repo.getPrivacy();
    expect((loaded as Success).value.profileVisible, isFalse);
  });
}
