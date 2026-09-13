final class SetActiveConversationUseCase {
  const SetActiveConversationUseCase(this._setActive);

  final void Function(String? conversationId) _setActive;

  void call(String? conversationId) => _setActive(conversationId);
}
