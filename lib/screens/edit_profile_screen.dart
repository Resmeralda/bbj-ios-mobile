import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../profile_store.dart';
import '../theme.dart';
import 'profile_screen.dart' show beltColor;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const belts = ['White', 'Blue', 'Purple', 'Brown', 'Black'];
  static const ageRanges = [
    'Under 18',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55+',
  ];

  final _form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController fitness;
  late final TextEditingController nutrition;
  late String belt;
  late String ageRange;
  late int weeklyGoal;

  @override
  void initState() {
    super.initState();
    final p = profileStore.profile;
    name = TextEditingController(text: p.name);
    fitness = TextEditingController(text: p.fitnessGoal);
    nutrition = TextEditingController(text: p.nutritionGoal);
    belt = p.belt;
    ageRange = ageRanges.contains(p.ageRange) ? p.ageRange : ageRanges[2];
    weeklyGoal = p.weeklyGoal;
  }

  @override
  void dispose() {
    name.dispose();
    fitness.dispose();
    nutrition.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    // TODO: also write to Cloud Firestore: users/{uid}
    profileStore.update(
      profileStore.profile.copyWith(
        name: name.text.trim(),
        belt: belt,
        ageRange: ageRange,
        weeklyGoal: weeklyGoal,
        fitnessGoal: fitness.text.trim(),
        nutritionGoal: nutrition.text.trim(),
      ),
    );
    context.pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit Profile'),
      backgroundColor: AppColors.home,
      foregroundColor: Colors.white,
    ),
    body: Form(
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
              for (final b in belts)
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
            items: ageRanges
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
            min: 1,
            max: 7,
            divisions: 6,
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.home,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: _save,
            child: const Text('Save Changes'),
          ),
        ],
      ),
    ),
  );
}
