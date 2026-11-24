import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../profile_store.dart';
import '../theme.dart';
import 'profile_screen.dart' show beltColor;

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key, this.store});

  final ProfileStore? store;

  @override
  Widget build(BuildContext context) {
    final profiles = store ?? profileStore;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.home,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: profiles,
        builder: (context, _) {
          if (profiles.hasLoaded) {
            return _ProfileForm(
              key: ObjectKey(profiles.account),
              store: profiles,
              account: profiles.account,
            );
          }
          if (profiles.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(profiles.loadError ?? 'Sign in to edit your profile.'),
                if (profiles.loadError != null)
                  TextButton(
                    onPressed: profiles.retryLoad,
                    child: const Text('Try again'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.store, required this.account});

  final ProfileStore store;
  final Object account;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController fitness;
  late final TextEditingController nutrition;
  late String belt;
  late String ageRange;
  late int weeklyGoal;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final p = widget.store.profile;
    name = TextEditingController(text: p.name);
    fitness = TextEditingController(text: p.fitnessGoal);
    nutrition = TextEditingController(text: p.nutritionGoal);
    belt = p.belt;
    ageRange = p.ageRange;
    weeklyGoal = p.weeklyGoal;
  }

  @override
  void dispose() {
    name.dispose();
    fitness.dispose();
    nutrition.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.store.save(
        UserProfile(
          name: name.text.trim(),
          belt: belt,
          ageRange: ageRange,
          weeklyGoal: weeklyGoal,
          fitnessGoal: fitness.text.trim(),
          nutritionGoal: nutrition.text.trim(),
        ),
        account: widget.account,
      );
    } catch (_) {
      if (!mounted || widget.store.account != widget.account) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not save your profile. Please try again.';
      });
      return;
    }
    if (!mounted || widget.store.account != widget.account) return;
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: _saving,
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.tint,
                  child: Text(
                    name.text.isEmpty ? '?' : name.text[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: AppColors.home),
                  ),
                ),
                TextButton.icon(
                  // TODO: image_picker + Firebase Storage upload
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo upload coming soon')),
                  ),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Change photo'),
                ),
              ],
            ),
          ),
          TextFormField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your name'
                : null,
          ),
          const SizedBox(height: 20),
          const Text('Belt', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final b in UserProfile.belts)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: beltColor(b),
                    radius: 8,
                  ),
                  label: Text(b),
                  selected: belt == b,
                  onSelected: (_) => setState(() => belt = b),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: ageRange,
            decoration: const InputDecoration(labelText: 'Age range'),
            items: UserProfile.ageRanges
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => ageRange = v!),
          ),
          const SizedBox(height: 20),
          Text(
            'Weekly training goal: $weeklyGoal sessions',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: weeklyGoal.toDouble(),
            min: UserProfile.minWeeklyGoal.toDouble(),
            max: UserProfile.maxWeeklyGoal.toDouble(),
            divisions: UserProfile.maxWeeklyGoal - UserProfile.minWeeklyGoal,
            label: '$weeklyGoal',
            onChanged: (v) => setState(() => weeklyGoal = v.round()),
          ),
          TextFormField(
            controller: fitness,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Fitness goal'),
          ),
          TextFormField(
            controller: nutrition,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Nutrition goal'),
          ),
          const SizedBox(height: 24),
          if (_saveError case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.home,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Changes'),
          ),
        ],
      ),
    ),
  );
}
