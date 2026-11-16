import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:overlay_support/overlay_support.dart';

// Core Imports
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/date_formatter.dart';
import 'shared/widgets/global_network_wrapper.dart';

// Feature Imports
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // 1. Ensure Flutter bindings are initialized before calling native plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for consistent mobile layout
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 2. Initialize Firebase & Background FCM Handler safely
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    log('⚠️ Firebase initialization error: $e');
  }

  // 3. Initialize Date Formatting for Russian Locale (Intl + DateFormatter)
  try {
    await initializeDateFormatting('ru_RU', null);
    await DateFormatter.initialize();
  } catch (e) {
    log('⚠️ DateFormatter initialization error: $e');
  }

  // 4. Create top-level Riverpod ProviderContainer
  final container = ProviderContainer();

  // 5. Pre-load Auth State (prevents login/home route flicker on startup)
  await container.read(authControllerProvider).checkInitialAuth();

  // 6. Initialize Push Notifications & Local Notification Channels
  try {
    final notificationService = container.read(notificationServiceProvider);
    await notificationService.initialize();
  } catch (e) {
    log('⚠️ NotificationService initialization error: $e');
  }

  // 7. Run the App wrapped in OverlaySupport.global for in-app chat banners
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: OverlaySupport.global(child: const KlincitiWorkerApp()),
    ),
  );
}

class KlincitiWorkerApp extends ConsumerWidget {
  const KlincitiWorkerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Klinciti Партнер',
      debugShowCheckedModeBanner: false,

      // Wraps the entire app to show "No Internet" banners globally
      builder: (context, child) {
        return GlobalNetworkWrapper(child: child ?? const SizedBox.shrink());
      },

      // ==========================================
      // THEMING (Forced Light Mode to match Slate/White UI cards)
      // ==========================================
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // ==========================================
      // LOCALIZATION (ru_RU)
      // ==========================================
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
      locale: const Locale('ru', 'RU'),

      // ==========================================
      // ROUTING
      // ==========================================
      routerConfig: router,
    );
  }
}
