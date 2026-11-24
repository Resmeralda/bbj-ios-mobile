import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ObjectKey;
import 'package:go_router/go_router.dart';

import 'data/review_store.dart';
import 'data/role_store.dart';
import 'profile_store.dart';
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
import 'screens/recovery_details_screen.dart';
import 'screens/recovery_settings_screen.dart';
import 'screens/recovery_week_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/trainer_access_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouter = _createDefaultRouter();

GoRouter _createDefaultRouter() {
  final auth = FirebaseAuth.instance;
  return createAppRouter(
    auth,
    roles: roleStore,
    reviews: ReviewStore(
      roles: roleStore,
      currentUid: () => auth.currentUser?.uid,
      accountClaims: () async => (await auth.currentUser?.getIdTokenResult(true))?.claims,
    ),
  );
}

GoRouter createAppRouter(
  FirebaseAuth auth, {
  ProfileStore? profiles,
  RoleStore? roles,
  ReviewStore? reviews,
}) => GoRouter(
  initialLocation: '/home',

  refreshListenable: Listenable.merge([
    GoRouterRefreshStream(auth.authStateChanges()),
    roles,
  ]),

  redirect: (context, state) {
    final user = auth.currentUser;
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
      builder: (context, state) => RegisterScreen(auth: auth, store: profiles),
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
              builder: (_, _) => HomeScreen(store: profiles),
              routes: [
                GoRoute(
                  path: 'profile',
                  builder: (_, _) => ProfileScreen(
                    store: profiles,
                    roles: roles,
                    auth: auth,
                    reviews: reviews,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, _) => EditProfileScreen(store: profiles),
                    ),
                    GoRoute(
                      path: 'admin',
                      redirect: (_, _) =>
                          reviews != null &&
                              roles?.verifiedRoleFor(auth.currentUser?.uid) ==
                                  UserRole.administrator
                          ? null
                          : '/home/profile',
                      builder: (_, _) => AdminDashboardScreen(
                        key: ObjectKey(roles!.access),
                        store: reviews!,
                      ),
                    ),
                    GoRoute(
                      path: 'submissions',
                      redirect: (_, _) =>
                          reviews != null &&
                              roles?.verifiedRoleFor(auth.currentUser?.uid) ==
                                  UserRole.trainer
                          ? null
                          : '/home/profile',
                      builder: (_, _) => MySubmissionsScreen(
                        key: ObjectKey(roles!.access),
                        store: reviews!,
                        uid: auth.currentUser!.uid,
                      ),
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
                  // `extra` is lost on web refresh / deep links, so don't hard-cast.
                  builder: (_, state) => LogSessionScreen(
                    session: state.extra is TrainingSession
                        ? state.extra as TrainingSession
                        : null,
                  ),
                ),
                GoRoute(
                  path: 'history',
                  builder: (_, _) => const HistoryScreen(),
                ),
                GoRoute(
                  path: 'techniques',
                  builder: (context, state) => TechniquesScreen(
                    initialCategory:
                        state.uri.queryParameters['category'] ?? 'All',
                    favoritesOnly:
                        state.uri.queryParameters['favorites'] == 'true',
                  ),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, state) => TechniqueDetailScreen(
                        techniqueId: state.pathParameters['id']!,
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
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (_, _) => const RecoveryDetailsScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (_, _) => const RecoverySettingsScreen(),
                ),
                GoRoute(
                  path: 'weekly',
                  builder: (_, _) => const RecoveryWeekScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
