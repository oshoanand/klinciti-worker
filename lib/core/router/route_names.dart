class AppRoutes {
  // Core
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';

  // Jobs (Standardized under `/jobs/*` namespace)
  static const String jobDashboard = '/dashboard';
  static const String jobList =
      '/jobs/list'; // Usage: '${AppRoutes.jobList}?status=ONGOING'
  static const String jobDetail =
      '/jobs/detail'; // Usage: '${AppRoutes.jobDetail}/$jobId'

  // Chats
  static const String chatList = '/chats';
  static const String chatDetail =
      '/chats/room'; // Usage: '${AppRoutes.chatDetail}/$sessionId'

  // Profile & Settings
  static const String profileDummy = '/profile-dummy';
  static const String profileEdit = '/profile/edit';
  static const String support = '/support';
  static const String notifications = '/notifications';

  // Worker Onboarding Flow (Standardized under `/worker/*` namespace)
  static const String workerResolve = '/worker/resolve';
  static const String workerStep2 = '/worker/step-2';
  static const String workerStep3 = '/worker/step-3';
  static const String workerStep4 = '/worker/step-4';
  static const String workerPendingReview = '/worker/pending-review';
  static const String workerRejected = '/worker/rejected';
}
