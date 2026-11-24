import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/role_store.dart';
import '../profile_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

Color beltColor(String belt) => switch (belt) {
  'Blue' => Colors.blue.shade700,
  'Purple' => Colors.purple,
  'Brown' => Colors.brown,
  'Black' => Colors.black,
  _ => Colors.white,
};

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.store, this.roles, this.auth});

  final ProfileStore? store;
  final RoleStore? roles;
  final FirebaseAuth? auth;

  ProfileStore get _profiles => store ?? profileStore;

  Future<void> _logout(BuildContext context) async {
    await (auth ?? FirebaseAuth.instance).signOut();

    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_profiles, roles]),
    builder: (context, _) {
      final p = _profiles.profile;
      final uid = auth?.currentUser?.uid;
      final role = roles?.verifiedRoleFor(uid);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.home,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/home/profile/edit'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_profiles.loading) const LinearProgressIndicator(),
            if (_profiles.loadError case final error?) Text(error),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.tint,
                child: Text(
                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 40, color: AppColors.home),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                p.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: beltColor(p.belt),
                  radius: 8,
                ),
                label: Text('${p.belt} belt'),
              ),
            ),
            const SizedBox(height: 16),
            if (roles != null)
              _Row(
                Icons.badge_outlined,
                'Role',
                role?.label ??
                    (roles!.statusFor(uid) == RoleStatus.loading
                        ? 'Checking access…'
                        : 'Role unavailable'),
              ),
            _Row(Icons.cake, 'Age range', p.ageRange),
            _Row(
              Icons.event_repeat,
              'Weekly training goal',
              '${p.weeklyGoal} sessions',
            ),
            _Row(Icons.fitness_center, 'Fitness goal', p.fitnessGoal),
            _Row(Icons.restaurant, 'Nutrition goal', p.nutritionGoal),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.home,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => context.push('/home/profile/edit'),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),

            if (role == UserRole.administrator) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  foregroundColor: AppColors.home,
                ),
                onPressed: () => context.go('/home/profile/admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin Dashboard'),
              ),
            ],

            const SizedBox(height: 12),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ],
        ),
      );
    },
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        Icon(icon, color: AppColors.home),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              Text(
                value.isEmpty ? 'Not set' : value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
