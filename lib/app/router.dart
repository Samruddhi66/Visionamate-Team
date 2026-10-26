import 'package:go_router/go_router.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/scene_analysis/screens/scene_analysis_screen.dart';
import '../features/navigation/screens/navigation_screen.dart';
import '../features/ocr/screens/ocr_screen.dart';
import '../features/currency_detection/screens/currency_screen.dart';
import '../features/object_recognition/screens/object_screen.dart';
import '../features/image_qa/screens/image_qa_screen.dart';
import '../features/emergency/screens/emergency_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/saved_places/screens/saved_places_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/safety_alerts/screens/obstacle_traffic_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/scene',
      builder: (context, state) => const SceneAnalysisScreen(),
    ),
    GoRoute(
      path: '/navigation',
      builder: (context, state) {
        final destination = state.extra as String?;
        return NavigationScreen(initialDestination: destination);
      },
    ),
    GoRoute(
      path: '/ocr',
      builder: (context, state) => const OcrScreen(),
    ),
    GoRoute(
      path: '/currency',
      builder: (context, state) => const CurrencyScreen(),
    ),
    GoRoute(
      path: '/object',
      builder: (context, state) => const ObjectRecognitionScreen(),
    ),
    GoRoute(
      path: '/emergency',
      builder: (context, state) => const EmergencyScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/saved',
      builder: (context, state) => const SavedPlacesScreen(),
    ),
    GoRoute(
      path: '/image-qa',
      builder: (context, state) => const ImageQaScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/obstacle-traffic',
      builder: (context, state) => const ObstacleTrafficScreen(),
    ),
  ],
);
