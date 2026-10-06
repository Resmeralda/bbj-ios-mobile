import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'shell.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/training_screen.dart';
import 'screens/log_session_screen.dart';
import 'screens/history_screen.dart';
import 'models/training_session.dart';
import 'screens/techniques_screen.dart';
import 'screens/technique_detail_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/recovery_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();

    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouter = GoRouter(
  initialLocation: '/home',

  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),

  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    final isLoginPage = state.matchedLocation == '/login';
    final isRegisterPage = state.matchedLocation == '/register';
    final isForgotPasswordPage =
        state.matchedLocation == '/forgot-password';

    final isAuthPage =
        isLoginPage || isRegisterPage || isForgotPasswordPage;

    // If the user is not logged in, keep them out of the main app.
    if (!isLoggedIn && !isAuthPage) {
      return '/login';
    }

    // If the user is already logged in, keep them out of
    // login/register/password reset pages.
    if (isLoggedIn && isAuthPage) {
      return '/home';
    }

    return null;
  },

  routes: [
    // Authentication routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Main application routes
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        // Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'profile',
                  builder: (_, _) => const ProfileScreen(),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, _) => const EditProfileScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Training
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/training',
              builder: (_, _) => const TrainingScreen(),
              routes: [
                GoRoute(
                  path: 'log',
                  builder: (_, state) => LogSessionScreen(
                    session: state.extra as TrainingSession?,
                  ),
                ),
                GoRoute(
                  path: 'history',
                  builder: (_, _) => const HistoryScreen(),
                ),
                GoRoute(
                  path: 'techniques',
                  builder: (_, _) => const TechniquesScreen(),
                  routes: [
                    GoRoute(
                      path: ':name',
                      builder: (_, state) => TechniqueDetailScreen(
                        name: state.pathParameters['name']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Nutrition
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/nutrition',
              builder: (_, _) => const NutritionScreen(),
            ),
          ],
        ),

        // Recovery
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/recovery',
              builder: (_, _) => const RecoveryScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);