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

// TODO: add a redirect that sends signed-out users to /login using
// FirebaseAuth.instance.authStateChanges() as refreshListenable.
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
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
                      builder: (_, s) => TechniqueDetailScreen(
                        name: s.pathParameters['name']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/nutrition',
              builder: (_, _) => const NutritionScreen(),
            ),
          ],
        ),
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
