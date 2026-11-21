import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/data/models/chat_session_model.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/chat/presentation/screens/chat_inbox_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/jobs/presentation/job_dashboard_screen.dart';
import '../../features/jobs/presentation/job_detail_screen.dart';
import '../../features/jobs/presentation/job_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/registration/presentation/onboarding_resolver_screen.dart';
import '../../features/registration/presentation/pending_review_screen.dart';
import '../../features/registration/presentation/rejected_screen.dart';
import '../../features/registration/presentation/step2_screen.dart';
import '../../features/registration/presentation/step3_screen.dart';
import '../../features/registration/presentation/step4_screen.dart';
import '../../features/payments/presentation/linked_cards_screen.dart';
import '../../features/payments/presentation/transactions_screen.dart';
import '../../shared/layouts/main_scaffold.dart';
import 'route_names.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Notifies GoRouter to re-evaluate `redirect` when auth or user status changes
/// WITHOUT destroying and recreating the GoRouter navigation stack.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(isAuthenticatedProvider, (previous, next) => notifyListeners());

    ref.listen(currentUserProvider, (prev, next) {
      final prevMod = prev?['moderationStatus'] ?? prev?['moderation_status'];
      final nextMod = next?['moderationStatus'] ?? next?['moderation_status'];
      final prevAuth = prev?['auth_status'] ?? prev?['authStatus'];
      final nextAuth = next?['auth_status'] ?? next?['authStatus'];
      final prevStep = prev?['onboardingStep'];
      final nextStep = next?['onboardingStep'];

      if (prevMod != nextMod || prevAuth != nextAuth || prevStep != nextStep) {
        notifyListeners();
      }
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,

    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      final location = state.matchedLocation;

      // 1. Show 2-page intro onboarding on first launch
      if (!hasSeenOnboarding && location != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }

      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final currentUser = ref.read(currentUserProvider);

      // 2. Protect restricted routes when unauthenticated
      final isRestrictedRoute =
          location.startsWith(AppRoutes.jobDashboard) ||
          location.startsWith('/jobs') ||
          location.startsWith(AppRoutes.chatList) ||
          location.startsWith(AppRoutes.chatDetail) ||
          location.startsWith(AppRoutes.notifications) ||
          location.startsWith(AppRoutes.profileEdit) ||
          location.startsWith(AppRoutes.support) ||
          location.startsWith('/worker/') ||
          location.startsWith(AppRoutes.workerResolve);

      if (isRestrictedRoute && !isAuthenticated) {
        return AppRoutes.login;
      }

      // 3. Authenticated user routing & onboarding/moderation guard
      if (isAuthenticated && currentUser != null) {
        final modStatus =
            (currentUser['moderationStatus'] ??
                    currentUser['moderation_status'] ??
                    'INCOMPLETE')
                .toString()
                .toUpperCase();

        final isUnapprovedWorker =
            modStatus == 'PENDING' ||
            modStatus == 'INCOMPLETE' ||
            modStatus == 'REJECTED';

        // If already logged in and sitting on /login, route appropriately
        if (location == AppRoutes.login) {
          return isUnapprovedWorker ? AppRoutes.workerResolve : AppRoutes.home;
        }

        // Allow /worker/*, /onboarding-resolver, /support, and /chats/room/* so
        // unapproved workers can complete registration or message support
        final isRegistrationOrSupportRoute =
            location.startsWith('/worker/') ||
            location.startsWith(AppRoutes.workerResolve) ||
            location.startsWith(AppRoutes.support) ||
            location.startsWith(AppRoutes.chatDetail);

        if (isUnapprovedWorker && !isRegistrationOrSupportRoute) {
          return AppRoutes.workerResolve;
        }
      }

      return null;
    },

    routes: [
      // ==========================================
      // BOTTOM NAVIGATION SHELL (TABS 0, 1, 2)
      // ==========================================
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          return FadeIndexedStack(
            index: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          // Tab 0: Home Screen
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Tab 1: Job Dashboard Screen
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.jobDashboard,
                builder: (context, state) => const JobDashboardScreen(),
              ),
            ],
          ),

          // Tab 2: Chat Inbox Screen
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chatList,
                builder: (context, state) => const ChatInboxScreen(),
              ),
            ],
          ),
        ],
      ),

      // ==========================================
      // JOBS FLOW PUSH ROUTES (LIST & DETAIL)
      // ==========================================
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.jobList, // '/jobs/list?status=...'
        builder: (context, state) {
          final status = state.uri.queryParameters['status'] ?? 'ACCEPTED';
          return JobListScreen(status: status);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${AppRoutes.jobDetail}/:id', // '/jobs/detail/:id'
        builder: (context, state) {
          final jobId = state.pathParameters['id']!;
          return JobDetailScreen(jobId: jobId);
        },
      ),

      GoRoute(
        path: AppRoutes.paymentMethods,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const LinkedCardsScreen(isWorkerPayoutMode: true),
      ),
      GoRoute(
        path: AppRoutes.workerTransactions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WorkerTransactionsScreen(),
      ),

      // ==========================================
      // CHAT DETAIL & SUPPORT ROUTES
      // ==========================================
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${AppRoutes.chatDetail}/:sessionId', // '/chats/room/:sessionId'
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          final query = state.uri.queryParameters;

          final extraSession = state.extra is ChatSessionModel
              ? state.extra as ChatSessionModel
              : null;
          final extraMap = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null;

          final resolvedPartnerId =
              (extraSession != null && extraSession.partnerId.isNotEmpty)
              ? extraSession.partnerId
              : (extraMap?['partnerId']?.toString() ??
                    query['partnerId'] ??
                    '');

          final resolvedPartnerName =
              extraSession?.partnerName ??
              extraMap?['partnerName']?.toString() ??
              query['partnerName'];

          final resolvedPartnerAvatar =
              extraSession?.partnerAvatar ??
              extraMap?['partnerAvatar']?.toString() ??
              query['partnerAvatar'];

          return ChatDetailScreen(
            sessionId: extraSession?.id ?? sessionId,
            partnerId: resolvedPartnerId,
            partnerName: resolvedPartnerName,
            partnerAvatar: resolvedPartnerAvatar,
            jobId: query['jobId'] ?? extraMap?['jobId']?.toString(),
            jobTitle: query['jobTitle'] ?? extraMap?['jobTitle']?.toString(),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.support, // '/support'
        builder: (context, state) => const ChatDetailScreen(
          sessionId: 'new_admin',
          partnerId: 'admin',
          partnerName: 'Служба поддержки',
        ),
      ),

      // ==========================================
      // NOTIFICATIONS & PROFILE EDIT ROUTES
      // ==========================================
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.notifications, // '/notifications'
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.profileEdit, // '/profile/edit'
        builder: (context, state) => const ProfileEditScreen(),
      ),

      // ==========================================
      // AUTH & WORKER ONBOARDING ROUTES
      // ==========================================
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.login,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.workerResolve,
        builder: (context, state) => const OnboardingResolverScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.workerStep2,
        builder: (context, state) => const Step2Screen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.workerStep3,
        builder: (context, state) => const Step3Screen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.workerStep4,
        builder: (context, state) => const Step4Screen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.workerPendingReview,
        builder: (context, state) => const PendingReviewScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.workerRejected,
        builder: (context, state) {
          final reason = state.extra is String ? state.extra as String : null;
          return RejectedScreen(initialReason: reason);
        },
      ),
    ],
  );
});
