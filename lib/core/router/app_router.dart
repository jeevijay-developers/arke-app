import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/otp_verification_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/forgot_otp_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/widgets/student_gate.dart';
import '../../features/courses/course_detail_screen.dart';
import '../../features/courses/course_player_screen.dart';
import '../../features/courses/courses_list_screen.dart';
import '../../features/courses/lecture_player_screen.dart';
import '../../features/dashboard/student_dashboard_screen.dart';
import '../../features/dashboard/doubts_screen.dart';
import '../../features/dashboard/qbank_screen.dart';
import '../../features/dashboard/educators_screen.dart';
import '../../features/dashboard/compete_screen.dart';
import '../../features/dashboard/analytics_screen.dart';
import '../../features/dashboard/leaderboard_screen.dart';
import '../../features/dashboard/favourites_screen.dart';
import '../../features/dashboard/store_screen.dart';
import '../../features/dashboard/Mylearning.dart';
import '../../features/home/home_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/live/live_list_screen.dart';
import '../../features/live/live_room_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/notifications_inbox_screen.dart';
import '../../features/profile/profile_dashboard_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/profile/privacy_policy_screen.dart';
import '../../features/profile/terms_of_service_screen.dart';
import '../../features/profile/coming_soon_screen.dart';
import '../../features/mentor_chat/mentor_chat_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/tests/test_engine_screen.dart';
import '../../features/tests/test_result_screen.dart';
import '../../features/tests/tests_list_screen.dart';
import '../providers.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Do NOT watch any frequently-changing providers here — watching causes the
  // entire GoRouter to be recreated (resetting navigation to /splash).
  // All state is read inside the redirect callback instead.
  final auth = ref.read(authRepositoryProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (ctx, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;
      // Read all state inside the callback — never watch in the provider body
      final resetInProgress = ref.read(passwordResetInProgressProvider);
      if (resetInProgress) return null;
      final signedIn = auth.isSignedIn || ref.read(authStateProvider);
      final atAuth = loc == '/login' || loc == '/signup' || loc == '/verify-otp';
      final atPasswordReset = loc == '/forgot' || loc == '/forgot-otp' || loc == '/reset-password';
      if (!signedIn && !atAuth && !atPasswordReset) return '/login';
      if (signedIn && atAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/forgot',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/forgot-otp',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ForgotOtpScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reset-password',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ResetPasswordScreen(
          source: state.uri.queryParameters['source'] ?? 'forgot',
        ),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (_, state) => OtpVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
          isGoogleFlow: state.uri.queryParameters['source'] == 'google',
        ),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (ctx, state, child) =>
            HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/courses',
            builder: (_, __) => const CoursesListScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileDashboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/tests',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TestsListScreen(),
      ),
      GoRoute(
        path: '/live',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const LiveListScreen(),
      ),
      GoRoute(
        path: '/course/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            CourseDetailScreen(courseId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/course-player/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => CoursePlayerScreen(
          courseId: s.pathParameters['id']!,
          initialLessonId: s.uri.queryParameters['lessonId'],
        ),
      ),
      GoRoute(
        path: '/lecture/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            LecturePlayerScreen(lectureId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/live/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => LiveRoomScreen(classId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/test/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TestEngineScreen(testId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/test-result/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TestResultScreen(attemptId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms-of-service',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationsInboxScreen(),
      ),
      GoRoute(
        path: '/student-dashboard',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: StudentDashboardScreen()),
      ),
      GoRoute(
        path: '/my-learning',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: MyLearningScreen()),
      ),
      GoRoute(
        path: '/doubts',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: DoubtsScreen()),
      ),
      GoRoute(
        path: '/qbank',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: QBankScreen()),
      ),
      GoRoute(
        path: '/educators',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: EducatorsScreen()),
      ),
      GoRoute(
        path: '/compete',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: CompeteScreen()),
      ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: AnalyticsScreen()),
      ),
      GoRoute(
        path: '/leaderboard',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: LeaderboardScreen()),
      ),
      GoRoute(
        path: '/favourites',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: FavouritesScreen()),
      ),
      GoRoute(
        path: '/store',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: StoreScreen()),
      ),
      GoRoute(
        path: '/mentor-chat',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StudentGate(child: MentorChatScreen()),
      ),
      GoRoute(
        path: '/coming-soon/:title',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ComingSoonScreen(title: s.pathParameters['title']!),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
