import 'package:flutter/material.dart';
import 'package:seyra/app/di/app_dependencies.dart';
import 'package:seyra/app/router/app_routes.dart';
import 'package:seyra/app/router/shell_home_page.dart';
import 'package:seyra/core/config/app_config.dart';
import 'package:seyra/features/auth/domain/entities/user.dart';
import 'package:seyra/features/auth/presentation/logout_dialog.dart';
import 'package:seyra/features/auth/presentation/pages/login_page.dart';
import 'package:seyra/features/auth/presentation/pages/register_page.dart';
import 'package:seyra/features/chat/domain/entities/conversation.dart';
import 'package:seyra/features/chat/presentation/pages/call_page.dart';
import 'package:seyra/features/chat/presentation/pages/chat_details_page.dart';
import 'package:seyra/features/chat/presentation/pages/room_admin_page.dart';
import 'package:seyra/features/chat/presentation/pages/conversation_page.dart';
import 'package:seyra/features/chat/presentation/pages/new_conversation_page.dart';
import 'package:seyra/features/chat/presentation/pages/new_group_page.dart';
import 'package:seyra/features/chat/presentation/pages/social_pages.dart';
import 'package:seyra/features/profile/presentation/pages/delete_account_page.dart';
import 'package:seyra/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:seyra/features/backup/presentation/pages/backup_settings_page.dart';
import 'package:seyra/features/backup/presentation/pages/restore_backup_page.dart';
import 'package:seyra/features/profile/presentation/pages/settings_detail_pages.dart';
import 'package:seyra/features/profile/presentation/pages/settings_page.dart';

/// Application routing. Session/auth redirects will be added later.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          builder: (context) => LoginPage(
            loginUseCase: AppDependencies.loginUseCase,
            onCreateAccount: () {
              Navigator.of(context).pushNamed(AppRoutes.register);
            },
            onAuthenticated: (session, password) async {
              await _syncBackupThenOpenShell(
                context,
                userId: session.user.id,
                password: password,
              );
            },
          ),
          settings: settings,
        );
      case AppRoutes.register:
        return MaterialPageRoute<void>(
          builder: (context) => RegisterPage(
            registerUseCase: AppDependencies.registerUseCase,
            onSignIn: () {
              Navigator.of(context).pushNamed(AppRoutes.login);
            },
            onAuthenticated: (session, password) async {
              await _syncBackupThenOpenShell(
                context,
                userId: session.user.id,
                password: password,
              );
            },
          ),
          settings: settings,
        );
      case AppRoutes.conversation:
        final conversationId = settings.arguments as String? ?? '';
        return MaterialPageRoute<void>(
          builder: (context) => ConversationPage(
            conversationId: conversationId,
            watchConversations: AppDependencies.watchConversationsUseCase,
            watchMessages: AppDependencies.watchMessagesUseCase,
            watchPeerTyping: AppDependencies.watchPeerTypingUseCase,
            sendMessage: AppDependencies.sendMessageUseCase,
            retryMessage: AppDependencies.retryMessageUseCase,
            deleteMessage: AppDependencies.deleteMessageUseCase,
            reactToMessage: AppDependencies.reactToMessageUseCase,
            markConversationRead: AppDependencies.markConversationReadUseCase,
            clearConversation: AppDependencies.clearConversationUseCase,
            setMuted: AppDependencies.setConversationMutedUseCase,
            setActiveConversation: AppDependencies.setActiveConversationUseCase,
            currentUserId: AppDependencies.chatRepository.currentUserId,
            resolveCurrentUserId: () =>
                AppDependencies.chatRepository.currentUserId,
            social: AppDependencies.chatSocial,
            onOpenDetails: (conversation) {
              Navigator.of(context).pushNamed(
                AppRoutes.chatDetails,
                arguments: conversation,
              );
            },
          ),
          settings: settings,
        );
      case AppRoutes.newChat:
        return MaterialPageRoute<void>(
          builder: (context) => NewConversationPage(
            searchUsers: AppDependencies.searchUsersUseCase,
            startDirectChat: AppDependencies.startDirectChatUseCase,
            onOpened: (id) {
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.conversation,
                arguments: id,
              );
            },
          ),
          settings: settings,
        );
      case AppRoutes.newGroup:
      case AppRoutes.newChannel:
        final isChannel = settings.name == AppRoutes.newChannel;
        return MaterialPageRoute<void>(
          builder: (context) => NewGroupPage(
            kind: isChannel ? ConversationKind.channel : ConversationKind.group,
            searchUsers: AppDependencies.searchUsersUseCase,
            startGroup: AppDependencies.startGroupUseCase,
            startChannel: AppDependencies.startChannelUseCase,
            onOpened: (id) {
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.conversation,
                arguments: id,
              );
            },
          ),
          settings: settings,
        );
      case AppRoutes.chatDetails:
        final conversation = settings.arguments as Conversation;
        return MaterialPageRoute<void>(
          builder: (context) => ChatDetailsPage(
            conversation: conversation,
            currentUserId: AppDependencies.chatRepository.currentUserId,
            listMembers: AppDependencies.listMembersUseCase,
            addMembers: AppDependencies.addMembersUseCase,
            removeMember: AppDependencies.removeMemberUseCase,
            setMemberRole: AppDependencies.setMemberRoleUseCase,
            leaveConversation: AppDependencies.leaveConversationUseCase,
            social: AppDependencies.chatSocial,
            onToggleMute: (muted) {
              AppDependencies.setConversationMutedUseCase(
                conversationId: conversation.id,
                muted: muted,
              );
              Navigator.of(context).pop();
            },
            onClearLocal: () {
              AppDependencies.clearConversationUseCase(conversation.id);
            },
            onLeft: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          settings: settings,
        );
      case AppRoutes.roomAdmin:
        final conversation = settings.arguments as Conversation;
        return MaterialPageRoute<void>(
          builder: (context) => RoomAdminPage(
            conversation: conversation,
            currentUserId: AppDependencies.chatRepository.currentUserId,
            listMembers: AppDependencies.listMembersUseCase,
            addMembers: AppDependencies.addMembersUseCase,
            removeMember: AppDependencies.removeMemberUseCase,
            setMemberRole: AppDependencies.setMemberRoleUseCase,
            social: AppDependencies.chatSocial,
          ),
          settings: settings,
        );
      case AppRoutes.settings:
        final user = settings.arguments as User;
        return MaterialPageRoute<void>(
          builder: (context) => SettingsPage(
            user: user,
            watchProfile: AppDependencies.watchProfileUseCase,
            watchPreferences: AppDependencies.watchPreferencesUseCase,
            updatePreferences: AppDependencies.updatePreferencesUseCase,
            getNotificationPreferences:
                AppDependencies.getNotificationPreferencesUseCase,
            updateNotificationPreferences:
                AppDependencies.updateNotificationPreferencesUseCase,
            pushCoordinator: AppDependencies.pushCoordinator,
            onEditProfile: () {
              Navigator.of(context).pushNamed(
                AppRoutes.editProfile,
                arguments: user,
              );
            },
            onUsername: (username) {
              Navigator.of(context).pushNamed(
                AppRoutes.username,
                arguments: username,
              );
            },
            onLogout: () async {
              final confirmed = await confirmLogout(context);
              if (!confirmed) {
                return;
              }
              await AppDependencies.logoutUseCase();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.home,
                  (route) => false,
                );
              }
              await AppDependencies.pushCoordinator.stop();
            },
            onDeleteAccount: () {
              Navigator.of(context).pushNamed(AppRoutes.deleteAccount);
            },
            onPrivacy: () {
              Navigator.of(context).pushNamed(AppRoutes.privacy);
            },
            onSessions: () {
              Navigator.of(context).pushNamed(AppRoutes.sessions);
            },
            onBots: () {
              Navigator.of(context).pushNamed(AppRoutes.bots);
            },
            onCalls: () {
              Navigator.of(context).pushNamed(AppRoutes.callHistory);
            },
            onEncryption: () {
              Navigator.of(context).pushNamed(AppRoutes.encryption);
            },
            onSecurity: () {
              Navigator.of(context).pushNamed(AppRoutes.security);
            },
            onAbout: () {
              Navigator.of(context).pushNamed(AppRoutes.about);
            },
            onStorage: () {
              Navigator.of(context).pushNamed(AppRoutes.storage);
            },
          ),
          settings: settings,
        );
      case AppRoutes.deleteAccount:
        return MaterialPageRoute<void>(
          builder: (context) => DeleteAccountPage(
            deleteAccount: AppDependencies.deleteAccountUseCase,
            onDeleted: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.home,
                (route) => false,
              );
            },
          ),
          settings: settings,
        );
      case AppRoutes.editProfile:
        final user = settings.arguments as User;
        return MaterialPageRoute<void>(
          builder: (context) => EditProfilePage(
            user: user,
            watchProfile: AppDependencies.watchProfileUseCase,
            updateProfile: AppDependencies.updateProfileUseCase,
            profileRepository: AppDependencies.profileRepository,
            onUsername: () {
              Navigator.of(context).pushNamed(
                AppRoutes.username,
                arguments: user.username,
              );
            },
          ),
          settings: settings,
        );
      case AppRoutes.globalSearch:
        return MaterialPageRoute<void>(
          builder: (_) => GlobalSearchPage(social: AppDependencies.chatSocial),
          settings: settings,
        );
      case AppRoutes.discoverChannels:
        return MaterialPageRoute<void>(
          builder: (_) => DiscoverChannelsPage(social: AppDependencies.chatSocial),
          settings: settings,
        );
      case AppRoutes.privacy:
        return MaterialPageRoute<void>(
          builder: (_) => PrivacyControlsPage(social: AppDependencies.chatSocial),
          settings: settings,
        );
      case AppRoutes.sessions:
        return MaterialPageRoute<void>(
          builder: (_) => SessionsPage(social: AppDependencies.chatSocial),
          settings: settings,
        );
      case AppRoutes.bots:
        return MaterialPageRoute<void>(
          builder: (_) => BotsPage(social: AppDependencies.chatSocial),
          settings: settings,
        );
      case AppRoutes.callHistory:
        return MaterialPageRoute<void>(
          builder: (_) => CallHistoryPage(
            social: AppDependencies.chatSocial,
            currentUserId: AppDependencies.chatRepository.currentUserId,
          ),
          settings: settings,
        );
      case AppRoutes.call:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute<void>(
          builder: (_) => CallPage(
            social: AppDependencies.chatSocial,
            conversationId: args['conversationId'] as String? ?? '',
            video: args['video'] == true,
            outgoing: args['outgoing'] != false,
            incomingPayload: args['payload'] as Map<String, dynamic>?,
            peerTitle: args['title'] as String? ?? '',
            peerId: args['peerId'] as String? ?? '',
            peerInitials: args['initials'] as String? ?? '',
            currentUserId: AppDependencies.chatRepository.currentUserId,
          ),
          settings: settings,
        );
      case AppRoutes.username:
        final username = settings.arguments as String? ?? '';
        return MaterialPageRoute<void>(
          builder: (_) => UsernamePage(
            currentUsername: username,
            changeUsername: AppDependencies.changeUsernameUseCase,
          ),
          settings: settings,
        );
      case AppRoutes.encryption:
        return MaterialPageRoute<void>(
          builder: (_) => const EncryptionInfoPage(),
          settings: settings,
        );
      case AppRoutes.security:
        return MaterialPageRoute<void>(
          builder: (context) => SecuritySettingsPage(
            onSessions: () => Navigator.of(context).pushNamed(AppRoutes.sessions),
            onPrivacy: () => Navigator.of(context).pushNamed(AppRoutes.privacy),
            onEncryption: () =>
                Navigator.of(context).pushNamed(AppRoutes.encryption),
            onBackup: AppDependencies.appConfig.authBackendMode ==
                    AuthBackendMode.http
                ? () => Navigator.of(context).pushNamed(AppRoutes.backup)
                : null,
            onRestoreBackup: AppDependencies.appConfig.authBackendMode ==
                    AuthBackendMode.http
                ? () => Navigator.of(context).pushNamed(AppRoutes.restoreBackup)
                : null,
          ),
          settings: settings,
        );
      case AppRoutes.backup:
        return MaterialPageRoute<void>(
          builder: (_) => BackupSettingsPage(
            userId: AppDependencies.chatRepository.currentUserId,
            backupService: AppDependencies.backupService,
          ),
          settings: settings,
        );
      case AppRoutes.restoreBackup:
        return MaterialPageRoute<void>(
          builder: (_) => RestoreBackupPage(
            userId: AppDependencies.chatRepository.currentUserId,
            backupService: AppDependencies.backupService,
          ),
          settings: settings,
        );
      case AppRoutes.about:
        return MaterialPageRoute<void>(
          builder: (_) => const AboutSeyraPage(),
          settings: settings,
        );
      case AppRoutes.storage:
        return MaterialPageRoute<void>(
          builder: (_) => const StorageUsagePage(),
          settings: settings,
        );
      case AppRoutes.home:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => ShellHomePage(
            restoreSessionUseCase: AppDependencies.restoreSessionUseCase,
            logoutUseCase: AppDependencies.logoutUseCase,
            watchConversationsUseCase: AppDependencies.watchConversationsUseCase,
            refreshConversationsUseCase: AppDependencies.refreshConversationsUseCase,
            watchProfileUseCase: AppDependencies.watchProfileUseCase,
            watchPreferencesUseCase: AppDependencies.watchPreferencesUseCase,
            getAccountUseCase: AppDependencies.getAccountUseCase,
          ),
          settings: settings,
        );
    }
  }

  static Future<void> _syncBackupThenOpenShell(
    BuildContext context, {
    required String userId,
    required String password,
  }) async {
    try {
      await AppDependencies.backupService.syncAfterPasswordAuth(
        userId: userId,
        password: password,
      );
    } catch (_) {
      // Login must still succeed even if backup sync fails.
    }
    if (!context.mounted) {
      return;
    }
    _openShell(context);
  }

  static void _openShell(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }
}
