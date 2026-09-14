import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:seyra/core/config/app_config.dart';
import 'package:seyra/core/crypto/key_backup_service.dart';
import 'package:seyra/core/network/http_api_client.dart';
import 'package:seyra/core/services/backup_api_service.dart';
import 'package:seyra/core/services/backup_service.dart';
import 'package:seyra/core/storage/durable_secure_storage.dart';
import 'package:seyra/core/storage/flutter_secure_storage_adapter.dart';
import 'package:seyra/core/storage/memory_secure_storage.dart';
import 'package:seyra/core/storage/secure_storage.dart';
import 'package:seyra/features/chat/domain/usecases/watch_incoming_alerts_use_case.dart';
import 'package:seyra/features/notifications/data/http_notification_repository.dart';
import 'package:seyra/features/notifications/data/local_notification_display.dart';
import 'package:seyra/features/notifications/data/notification_display.dart';
import 'package:seyra/features/notifications/data/push_coordinator.dart';
import 'package:seyra/features/notifications/domain/repositories/notification_repository.dart';
import 'package:seyra/features/notifications/domain/usecases/notification_use_cases.dart';
import 'package:seyra/app/router/app_navigator.dart';
import 'package:seyra/app/router/app_routes.dart';
import 'package:seyra/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/datasources/http_auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/datasources/mock_auth_remote_data_source.dart';
import 'package:seyra/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:seyra/features/auth/domain/repositories/auth_repository.dart';
import 'package:seyra/features/auth/domain/usecases/delete_account_use_case.dart';
import 'package:seyra/features/auth/domain/usecases/login_use_case.dart';
import 'package:seyra/features/auth/domain/usecases/logout_use_case.dart';
import 'package:seyra/features/auth/domain/usecases/refresh_session_use_case.dart';
import 'package:seyra/features/auth/domain/usecases/register_use_case.dart';
import 'package:seyra/features/auth/domain/usecases/restore_session_use_case.dart';
import 'package:seyra/features/chat/data/datasources/chat_data_source.dart';
import 'package:seyra/features/chat/data/datasources/http_chat_data_source.dart';
import 'package:seyra/features/chat/data/datasources/mock_chat_data_source.dart';
import 'package:seyra/features/chat/data/realtime/chat_realtime_impl.dart';
import 'package:seyra/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:seyra/features/chat/data/repositories/http_chat_social_repository.dart';
import 'package:seyra/features/chat/data/repositories/mock_chat_social_repository.dart';
import 'package:seyra/features/chat/domain/repositories/chat_repository.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';
import 'package:seyra/features/chat/domain/usecases/clear_conversation_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/delete_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/get_conversation_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/mark_conversation_read_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/react_to_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/refresh_conversations_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/retry_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/search_users_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/set_active_conversation_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/set_conversation_muted_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_direct_chat_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_group_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/start_channel_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/room_member_use_cases.dart';
import 'package:seyra/features/chat/domain/usecases/watch_conversations_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_messages_use_case.dart';
import 'package:seyra/features/chat/domain/usecases/watch_peer_typing_use_case.dart';
import 'package:seyra/core/theme/theme_controller.dart';
import 'package:seyra/features/profile/data/datasources/http_profile_data_source.dart';
import 'package:seyra/features/profile/data/datasources/mock_profile_data_source.dart';
import 'package:seyra/features/profile/data/datasources/profile_data_source.dart';
import 'package:seyra/features/profile/data/repositories/account_repository_impl.dart';
import 'package:seyra/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:seyra/features/profile/domain/repositories/account_repository.dart';
import 'package:seyra/features/profile/domain/repositories/profile_repository.dart';
import 'package:seyra/features/profile/domain/usecases/change_username_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/get_account_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/update_preferences_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/update_profile_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/watch_preferences_use_case.dart';
import 'package:seyra/features/profile/domain/usecases/watch_profile_use_case.dart';

/// Composition root.
///
/// Swap [authRemoteDataSource] to a real API adapter later. Domain and UI stay.
abstract final class AppDependencies {
  static late AppConfig appConfig;
  static late AuthRemoteDataSource authRemoteDataSource;
  static late AuthRepository authRepository;
  static late LoginUseCase loginUseCase;
  static late RegisterUseCase registerUseCase;
  static late LogoutUseCase logoutUseCase;
  static late RestoreSessionUseCase restoreSessionUseCase;
  static late RefreshSessionUseCase refreshSessionUseCase;
  static late DeleteAccountUseCase deleteAccountUseCase;
  static late AccountRepository accountRepository;
  static late GetAccountUseCase getAccountUseCase;
  static late ChatDataSource chatDataSource;
  static late ChatRepository chatRepository;
  static late ChatSocialRepository chatSocial;
  static late WatchConversationsUseCase watchConversationsUseCase;
  static late WatchMessagesUseCase watchMessagesUseCase;
  static late WatchPeerTypingUseCase watchPeerTypingUseCase;
  static late GetConversationUseCase getConversationUseCase;
  static late SendMessageUseCase sendMessageUseCase;
  static late StartDirectChatUseCase startDirectChatUseCase;
  static late StartGroupUseCase startGroupUseCase;
  static late StartChannelUseCase startChannelUseCase;
  static late ListMembersUseCase listMembersUseCase;
  static late AddMembersUseCase addMembersUseCase;
  static late RemoveMemberUseCase removeMemberUseCase;
  static late SetMemberRoleUseCase setMemberRoleUseCase;
  static late LeaveConversationUseCase leaveConversationUseCase;
  static late SearchUsersUseCase searchUsersUseCase;
  static late RefreshConversationsUseCase refreshConversationsUseCase;
  static late RetryMessageUseCase retryMessageUseCase;
  static late SetActiveConversationUseCase setActiveConversationUseCase;
  static late DeleteMessageUseCase deleteMessageUseCase;
  static late ReactToMessageUseCase reactToMessageUseCase;
  static late MarkConversationReadUseCase markConversationReadUseCase;
  static late ClearConversationUseCase clearConversationUseCase;
  static late SetConversationMutedUseCase setConversationMutedUseCase;
  static late ProfileDataSource profileDataSource;
  static late ProfileRepository profileRepository;
  static late WatchProfileUseCase watchProfileUseCase;
  static late UpdateProfileUseCase updateProfileUseCase;
  static late WatchPreferencesUseCase watchPreferencesUseCase;
  static late UpdatePreferencesUseCase updatePreferencesUseCase;
  static late ChangeUsernameUseCase changeUsernameUseCase;
  static late ThemeController themeController;
  static late NotificationRepository notificationRepository;
  static late RegisterDeviceUseCase registerDeviceUseCase;
  static late UnregisterDeviceUseCase unregisterDeviceUseCase;
  static late GetNotificationPreferencesUseCase getNotificationPreferencesUseCase;
  static late UpdateNotificationPreferencesUseCase
      updateNotificationPreferencesUseCase;
  static late WatchIncomingAlertsUseCase watchIncomingAlertsUseCase;
  static late PushCoordinator pushCoordinator;
  static late SecureStorage secureStorage;
  static late BackupService backupService;

  static Future<void> initialize({
    AppConfig? config,
    AuthRemoteDataSource? remoteDataSource,
    ChatDataSource? chatSource,
    ProfileDataSource? profileSource,
  }) async {
    appConfig = config ?? AppConfig.fromEnvironment();
    appConfig.validate();

    final httpMode = appConfig.authBackendMode == AuthBackendMode.http &&
        remoteDataSource == null;
    secureStorage = httpMode
        ? await _createHttpSecureStorage()
        : MemorySecureStorage();

    authRemoteDataSource =
        remoteDataSource ??
        _createAuthRemoteDataSource();
    authRepository = AuthRepositoryImpl(
      remoteDataSource: authRemoteDataSource,
    );
    loginUseCase = LoginUseCase(authRepository);
    registerUseCase = RegisterUseCase(authRepository);
    logoutUseCase = LogoutUseCase(authRepository);
    restoreSessionUseCase = RestoreSessionUseCase(authRepository);
    refreshSessionUseCase = RefreshSessionUseCase(authRepository);
    deleteAccountUseCase = DeleteAccountUseCase(authRepository);
    accountRepository = AccountRepositoryImpl(
      remoteDataSource: authRemoteDataSource,
    );
    getAccountUseCase = GetAccountUseCase(accountRepository);

    chatDataSource =
        chatSource ??
        (remoteDataSource != null
            ? MockChatDataSource(
                deliveryDelay: const Duration(milliseconds: 400),
              )
            : _createChatDataSource());
    chatRepository = ChatRepositoryImpl(dataSource: chatDataSource);
    final source = chatDataSource;
    chatSocial = source is HttpChatDataSource
        ? HttpChatSocialRepository(source)
        : MockChatSocialRepository();
    watchConversationsUseCase = WatchConversationsUseCase(chatRepository);
    watchMessagesUseCase = WatchMessagesUseCase(chatRepository);
    watchPeerTypingUseCase = WatchPeerTypingUseCase(chatRepository);
    getConversationUseCase = GetConversationUseCase(chatRepository);
    sendMessageUseCase = SendMessageUseCase(chatRepository);
    startDirectChatUseCase = StartDirectChatUseCase(chatRepository);
    startGroupUseCase = StartGroupUseCase(chatRepository);
    startChannelUseCase = StartChannelUseCase(chatRepository);
    listMembersUseCase = ListMembersUseCase(chatRepository);
    addMembersUseCase = AddMembersUseCase(chatRepository);
    removeMemberUseCase = RemoveMemberUseCase(chatRepository);
    setMemberRoleUseCase = SetMemberRoleUseCase(chatRepository);
    leaveConversationUseCase = LeaveConversationUseCase(chatRepository);
    searchUsersUseCase = SearchUsersUseCase(chatRepository);
    refreshConversationsUseCase = RefreshConversationsUseCase(chatRepository);
    retryMessageUseCase = RetryMessageUseCase(chatRepository);
    setActiveConversationUseCase = SetActiveConversationUseCase(
      chatRepository.setActiveConversation,
    );
    deleteMessageUseCase = DeleteMessageUseCase(chatRepository);
    reactToMessageUseCase = ReactToMessageUseCase(chatRepository);
    markConversationReadUseCase = MarkConversationReadUseCase(chatRepository);
    clearConversationUseCase = ClearConversationUseCase(chatRepository);
    setConversationMutedUseCase = SetConversationMutedUseCase(chatRepository);

    themeController = ThemeController();
    profileDataSource = profileSource ??
        (httpMode
            ? HttpProfileDataSource(
                apiClient: HttpApiClient(),
                secureStorage: secureStorage,
                baseUrl: Uri.parse(appConfig.apiBaseUrl),
                themeController: themeController,
              )
            : MockProfileDataSource(themeController: themeController));
    profileRepository = ProfileRepositoryImpl(dataSource: profileDataSource);
    watchProfileUseCase = WatchProfileUseCase(profileRepository);
    updateProfileUseCase = UpdateProfileUseCase(profileRepository);
    watchPreferencesUseCase = WatchPreferencesUseCase(profileRepository);
    updatePreferencesUseCase = UpdatePreferencesUseCase(profileRepository);
    changeUsernameUseCase = ChangeUsernameUseCase(profileRepository);

    notificationRepository = httpMode
        ? HttpNotificationRepository(
            apiClient: HttpApiClient(),
            secureStorage: secureStorage,
            baseUrl: Uri.parse(appConfig.apiBaseUrl),
          )
        : MemoryNotificationRepository();
    registerDeviceUseCase = RegisterDeviceUseCase(notificationRepository);
    unregisterDeviceUseCase = UnregisterDeviceUseCase(notificationRepository);
    getNotificationPreferencesUseCase = GetNotificationPreferencesUseCase(
      notificationRepository,
    );
    updateNotificationPreferencesUseCase = UpdateNotificationPreferencesUseCase(
      notificationRepository,
    );
    watchIncomingAlertsUseCase = WatchIncomingAlertsUseCase(chatRepository);
    pushCoordinator = PushCoordinator(
      registerDevice: registerDeviceUseCase,
      unregisterDevice: unregisterDeviceUseCase,
      watchAlerts: watchIncomingAlertsUseCase,
      display: httpMode
          ? LocalNotificationDisplay()
          : NoopNotificationDisplay(),
      secureStorage: secureStorage,
      openConversation: (id) {
        AppNavigator.key.currentState?.pushNamed(
          AppRoutes.conversation,
          arguments: id,
        );
      },
    );

    final keyBackup = KeyBackupService(secureStorage);
    final backupApi = httpMode
        ? BackupApiService(
            apiClient: HttpApiClient(),
            secureStorage: secureStorage,
            baseUrl: Uri.parse(appConfig.apiBaseUrl),
          )
        : null;
    backupService = BackupService(
      keyBackup: keyBackup,
      api: backupApi ?? BackupApiService(
        apiClient: HttpApiClient(),
        secureStorage: secureStorage,
        baseUrl: Uri.parse(appConfig.apiBaseUrl),
      ),
      secureStorage: secureStorage,
      onRestored: httpMode && chatDataSource is HttpChatDataSource
          ? (userId) => (chatDataSource as HttpChatDataSource)
              .restoreAfterBackup(userId)
          : null,
    );
    if (httpMode && chatDataSource is HttpChatDataSource) {
      final httpChat = chatDataSource as HttpChatDataSource;
      httpChat.onKeysPublished = (userId) {
        return backupService.tryUploadWithStoredSecret(userId);
      };
      httpChat.onOutboxUpdated = (userId) {
        return backupService.tryUploadWithStoredSecret(userId);
      };
    }
  }

  static AuthRemoteDataSource _createAuthRemoteDataSource() {
    if (appConfig.authBackendMode == AuthBackendMode.mock) {
      return MockAuthRemoteDataSource(
        latency: const Duration(milliseconds: 400),
      );
    }
    return HttpAuthRemoteDataSource(
      apiClient: HttpApiClient(),
      secureStorage: secureStorage,
      baseUrl: Uri.parse(appConfig.apiBaseUrl),
    );
  }

  static Future<SecureStorage> _createHttpSecureStorage() async {
    try {
      final support = await getApplicationSupportDirectory();
      return DurableSecureStorage(
        inner: FlutterSecureStorageAdapter(),
        directory: Directory(
          '${support.path}${Platform.pathSeparator}seyra_e2e',
        ),
      );
    } catch (_) {
      return FlutterSecureStorageAdapter();
    }
  }

  static ChatDataSource _createChatDataSource() {
    if (appConfig.authBackendMode == AuthBackendMode.mock) {
      return MockChatDataSource(
        deliveryDelay: const Duration(milliseconds: 400),
      );
    }
    return HttpChatDataSource(
      apiClient: HttpApiClient(),
      secureStorage: secureStorage,
      authRemote: authRemoteDataSource,
      baseUrl: Uri.parse(appConfig.apiBaseUrl),
      realtime: IoChatRealtime(),
    );
  }
}
