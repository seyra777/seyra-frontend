import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/notifications/domain/entities/notification_models.dart';

final class WatchIncomingAlertsUseCase {
  const WatchIncomingAlertsUseCase(this._repository);

  final ChatRepository _repository;

  Stream<IncomingAlert> call() => _repository.watchIncomingAlerts();
}
