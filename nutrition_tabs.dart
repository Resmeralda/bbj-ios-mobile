import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../models/health_models.dart';
import '../models/training_session.dart' show formatDate;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';

// ───────────────────── Progress (food log + weight log) ─────────────────────

class NutritionProgressTab extends StatelessWidget {
  const NutritionProgressTab({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([weightStore, goalsStore, foodStore]),
    builder: (context, _) {
      // ── weight data
      final entries = weightStore.items; // newest first
      final goals = goalsStore.goals;
      final goal = goals.goalWeight;
      final current = entries.isEmpty ? null : entries.first.pounds;
      final start = entries.isEmpty ? null : entries.last.pounds;

      var progress = 0.0;
      if (current != null && start != null && goal > 0 && goal != start) {
        progress = ((current - start) / (goal - start))
            .clamp(0.0, 1.0)
            .toDouble();
      }

      final change = (current != null && start != null)
          ? current - start
          : null;
      final recent = entries.take(8).toList().reversed.toList();

      // ── food data
      final foods = foodStore.items; // newest first
      final now = DateTime.now();
      bool isToday(DateTime d) =>
          d.year == now.year && d.month == now.month && d.day == now.day;
      final todays = foods.where((f) => isToday(f.date)).toList();
      final todayCal = todays.fold<int>(0, (a, f) => a + f.calories);
      final todayProtein = todays.fold<int>(0, (a, f) => a + f.protein);
      final calProgress = goals.calories == 0 ? 0.0 : todayCal / goals.calories;

      final foodTiles = <Widget>[];
      DateTime? lastDay;
      for (final f in foods) {
        final day = DateTime(f.date.year, f.date.month, f.date.day);
        if (day != lastDay) {
          foodTiles.add(
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                isToday(f.date) ? 'Today' : formatDate(f.date),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.muted,
                ),
              ),
            ),
          );
          lastDay = day;
        }
        foodTiles.add(
          EntryTile(
            icon: _mealIcon(f.meal),
            color: AppColors.nutrition,
            title: f.name,
            subtitle: [
              f.meal,
              if (f.calories > 0) '${f.calories} cal',
              if (f.protein > 0) '${f.protein} g protein',
            ].join('  •  '),
            onTap: () => showFormSheet(context, _FoodForm(existing: f)),
            onDelete: () async {
              if (await confirmDelete(context, 'food entry')) {
                foodStore.delete(f.id);
              }
            },
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AddButton(
                  label: 'Log Food',
                  icon: Icons.restaurant,
                  color: AppColors.nutrition,
                  onPressed: () => showFormSheet(context, const _FoodForm()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AddButton(
                  label: 'Log Weight',
                  icon: Icons.monitor_weight_outlined,
                  color: AppColors.nutrition,
                  onPressed: () => showFormSheet(context, const _WeightForm()),
                ),
              ),
            ],
          ),

          // ── Food log
          const SectionHeader('Food Log'),
          AppCard(
            color: const Color(0xFFE6F3E8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today', style: TextStyle(fontSize: 12)),
                Text(
                  '$todayCal / ${goals.calories} cal',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ProgressBar(calProgress, AppColors.nutrition),
                const SizedBox(height: 4),
                Text(
                  '$todayProtein g of ${goals.protein} g protein',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (foodStore.error != null) EmptyState(foodStore.error!),
          if (foods.isEmpty && foodStore.error == null)
            EmptyState(
              foodStore.loading
                  ? 'Loading…'
                  : 'Nothing logged yet. Tap Log Food to add what you ate.',
            ),
          ...foodTiles,

          // ── Weight log
          const SectionHeader('Weight Log'),
          StatRow([
            StatCard(
              'Current',
              current == null ? '—' : '${oneDecimal(current)} lbs',
            ),
            StatCard('Goal', goal > 0 ? '${oneDecimal(goal)} lbs' : 'Not set'),
            StatCard(
              'Change',
              change == null
                  ? '—'
                  : '${change > 0 ? '+' : ''}${oneDecimal(change)} lbs',
              color: const Color(0xFFE6F3E8),
            ),
          ]),
          if (goal > 0 && entries.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progress to goal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(progress, AppColors.nutrition),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).round()}% of the way from '
                    '${oneDecimal(start!)} to ${oneDecimal(goal)} lbs',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          if (recent.length >= 2) _WeightChart(recent),
          if (weightStore.error != null) EmptyState(weightStore.error!),
          if (entries.isEmpty && weightStore.error == null)
            EmptyState(
              weightStore.loading
                  ? 'Loading…'
                  : 'No weigh-ins yet. Tap Log Weight to add one.',
            ),
          for (final e in entries)
            EntryTile(
              icon: Icons.monitor_weight_outlined,
              color: AppColors.nutrition,
              title: '${oneDecimal(e.pounds)} lbs',
              subtitle: formatDate(e.date),
              onTap: () => showFormSheet(context, _WeightForm(existing: e)),
              onDelete: () async {
                if (await confirmDelete(context, 'weigh-in')) {
                  weightStore.delete(e.id);
                }
              },
            ),
        ],
      );
    },
  );
}

IconData _mealIcon(String meal) => switch (meal) {
  'Breakfast' => Icons.free_breakfast,
  'Lunch' => Icons.lunch_dining,
  'Dinner' => Icons.dinner_dining,
  _ => Icons.apple,
};

/// Bars for the most recent weigh-ins, oldest on the left.
class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const _WeightChart(this.entries);

  @override
  Widget build(BuildContext context) {
    final values = entries.map((e) => e.pounds);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    return AppCard(
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in entries)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      oneDecimal(e.pounds),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 20 + 60 * (e.pounds - lo) / span,
                      decoration: BoxDecoration(
                        color: AppColors.nutrition.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeightForm extends StatefulWidget {
  final WeightEntry? existing;
  const _WeightForm({this.existing});
  @override
  State<_WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<_WeightForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController weight;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    weight = TextEditingController(text: e == null ? '' : e.pounds.toString());
    date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    weightStore.save(
      WeightEntry(
        id: widget.existing?.id ?? weightStore.newId(),
        date: date,
        pounds: double.parse(weight.text),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.existing == null ? 'Log weight' : 'Edit weight'),
        TextFormField(
          controller: weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (lbs)'),
          validator: requiredPositive,
        ),
        DateField(date: date, onChanged: (d) => setState(() => date = d)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.nutrition,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _FoodForm extends StatefulWidget {
  final FoodEntry? existing;
  const _FoodForm({this.existing});
  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController name, calories, protein;
  late DateTime date;
  late String meal;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    name = TextEditingController(text: f?.name ?? '');
    calories = TextEditingController(
      text: (f == null || f.calories == 0) ? '' : '${f.calories}',
    );
    protein = TextEditingController(
      text: (f == null || f.protein == 0) ? '' : '${f.protein}',
    );
    date = f?.date ?? DateTime.now();
    final hour = DateTime.now().hour;
    meal =
        f?.meal ??
        (hour < 11
            ? 'Breakfast'
            : hour < 15
            ? 'Lunch'
            : hour < 21
            ? 'Dinner'
            : 'Snack');
  }

  @override
  void dispose() {
    name.dispose();
    calories.dispose();
    protein.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    foodStore.save(
      FoodEntry(
        id: widget.existing?.id ?? foodStore.newId(),
        date: date,
        meal: meal,
        name: name.text.trim(),
        calories: (double.tryParse(calories.text) ?? 0).round(),
        protein: (double.tryParse(protein.text) ?? 0).round(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.existing == null ? 'Log food' : 'Edit food'),
        Wrap(
          spacing: 8,
          children: [
            for (final t in mealTypes)
              ChoiceChip(
                label: Text(t),
                selected: meal == t,
                onSelected: (_) => setState(() => meal = t),
              ),
          ],
        ),
        TextFormField(
          controller: name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What did you eat?',
            hintText: 'Chicken, rice, broccoli',
          ),
          validator: (v) => requiredText(v, 'Please enter what you ate'),
        ),
        TextFormField(
          controller: calories,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Calories (optional)'),
          validator: optionalNumber,
        ),
        TextFormField(
          controller: protein,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Protein in g (optional)',
          ),
          validator: optionalNumber,
        ),
        DateField(date: date, onChanged: (d) => setState(() => date = d)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.nutrition,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ───────────────────────── Goals ─────────────────────────

class NutritionGoalsTab extends StatelessWidget {
  const NutritionGoalsTab({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: goalsStore,
    builder: (context, _) {
      final g = goalsStore.goals;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddButton(
            label: 'Edit Goals',
            icon: Icons.edit,
            color: AppColors.nutrition,
            onPressed: () => showFormSheet(context, _GoalsForm(goals: g)),
          ),
          _GoalRow(
            Icons.local_fire_department,
            'Daily calories',
            '${g.calories} cal',
            Colors.deepOrange,
          ),
          _GoalRow(Icons.egg_alt, 'Protein', '${g.protein} g', Colors.blue),
          _GoalRow(Icons.grain, 'Carbs', '${g.carbs} g', Colors.amber.shade800),
          _GoalRow(Icons.opacity, 'Fat', '${g.fat} g', Colors.purple),
          _GoalRow(
            Icons.water_drop,
            'Water',
            '${g.waterOz} oz',
            Colors.lightBlue,
          ),
          _GoalRow(
            Icons.flag,
            'Goal weight',
            g.goalWeight > 0 ? '${oneDecimal(g.goalWeight)} lbs' : 'Not set',
            AppColors.nutrition,
          ),
        ],
      );
    },
  );
}

class _GoalRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _GoalRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    ),
  );
}

class _GoalsForm extends StatefulWidget {
  final NutritionGoals goals;
  const _GoalsForm({required this.goals});
  @override
  State<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends State<_GoalsForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController calories, protein, carbs, fat, water, weight;

  @override
  void initState() {
    super.initState();
    final g = widget.goals;
    calories = TextEditingController(text: '${g.calories}');
    protein = TextEditingController(text: '${g.protein}');
    carbs = TextEditingController(text: '${g.carbs}');
    fat = TextEditingController(text: '${g.fat}');
    water = TextEditingController(text: '${g.waterOz}');
    weight = TextEditingController(
      text: g.goalWeight > 0 ? g.goalWeight.toString() : '',
    );
  }

  @override
  void dispose() {
    for (final c in [calories, protein, carbs, fat, water, weight]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    goalsStore.save(
      NutritionGoals(
        calories: int.parse(calories.text),
        protein: int.parse(protein.text),
        carbs: int.parse(carbs.text),
        fat: int.parse(fat.text),
        waterOz: int.parse(water.text),
        goalWeight: double.tryParse(weight.text) ?? 0,
      ),
    );
    Navigator.of(context).pop();
  }

  String? _wholeNumber(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n <= 0) ? 'Enter a whole number above 0' : null;
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool decimal = false,
  }) => TextFormField(
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(labelText: label),
    validator: decimal ? optionalNumber : _wholeNumber,
  );

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Nutrition goals'),
        _field(calories, 'Daily calories'),
        _field(protein, 'Protein (g)'),
        _field(carbs, 'Carbs (g)'),
        _field(fat, 'Fat (g)'),
        _field(water, 'Water (oz)'),
        _field(weight, 'Goal weight (lbs, optional)', decimal: true),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.nutrition,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _save,
          child: const Text('Save Goals'),
        ),
      ],
    ),
  );
}

// ───────────────────────── Recipes ─────────────────────────

class NutritionRecipesTab extends StatelessWidget {
  const NutritionRecipesTab({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: recipeStore,
    builder: (context, _) {
      final recipes = recipeStore.items;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddButton(
            label: 'Add Recipe',
            color: AppColors.nutrition,
            onPressed: () => showFormSheet(context, const _RecipeForm()),
          ),
          if (recipeStore.error != null) EmptyState(recipeStore.error!),
          if (recipes.isEmpty && recipeStore.error == null)
            EmptyState(
              recipeStore.loading
                  ? 'Loading…'
                  : 'No recipes yet. Tap Add Recipe to save your first one.',
            ),
          for (final r in recipes)
            EntryTile(
              icon: Icons.menu_book,
              color: AppColors.nutrition,
              title: r.name,
              subtitle: '${r.calories} cal  •  ${r.protein} g protein',
              extra: '${r.ingredientList.length} ingredients',
              onTap: () => showFormSheet(
                context,
                _RecipeDetail(
                  recipe: r,
                  onEdit: () =>
                      showFormSheet(context, _RecipeForm(existing: r)),
                  onDelete: () async {
                    if (await confirmDelete(context, 'recipe')) {
                      recipeStore.delete(r.id);
                    }
                  },
                ),
              ),
              onDelete: () async {
                if (await confirmDelete(context, 'recipe')) {
                  recipeStore.delete(r.id);
                }
              },
            ),
        ],
      );
    },
  );
}

class _RecipeDetail extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onEdit, onDelete;
  const _RecipeDetail({
    required this.recipe,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ingredients = recipe.ingredientList;
    final steps = recipe.stepList;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetTitle(recipe.name),
        Text(
          '${recipe.calories} cal  •  ${recipe.protein} g protein',
          style: const TextStyle(color: AppColors.muted),
        ),
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Ingredients',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          for (final i in ingredients) Text('•  $i'),
        ],
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Steps', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (var n = 0; n < steps.length; n++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${n + 1}. ${steps[n]}'),
            ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecipeForm extends StatefulWidget {
  final Recipe? existing;
  const _RecipeForm({this.existing});
  @override
  State<_RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<_RecipeForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController name, calories, protein, ingredients, steps;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    name = TextEditingController(text: r?.name ?? '');
    calories = TextEditingController(text: r == null ? '' : '${r.calories}');
    protein = TextEditingController(text: r == null ? '' : '${r.protein}');
    ingredients = TextEditingController(text: r?.ingredients ?? '');
    steps = TextEditingController(text: r?.steps ?? '');
  }

  @override
  void dispose() {
    for (final c in [name, calories, protein, ingredients, steps]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    recipeStore.save(
      Recipe(
        id: widget.existing?.id ?? recipeStore.newId(),
        name: name.text.trim(),
        calories: (double.tryParse(calories.text) ?? 0).round(),
        protein: (double.tryParse(protein.text) ?? 0).round(),
        ingredients: ingredients.text.trim(),
        steps: steps.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.existing == null ? 'Add recipe' : 'Edit recipe'),
        TextFormField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Recipe name'),
          validator: (v) => requiredText(v, 'Please enter a name'),
        ),
        TextFormField(
          controller: calories,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Calories (optional)'),
          validator: optionalNumber,
        ),
        TextFormField(
          controller: protein,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Protein in g (optional)',
          ),
          validator: optionalNumber,
        ),
        TextFormField(
          controller: ingredients,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Ingredients',
            hintText: 'One per line',
          ),
        ),
        TextFormField(
          controller: steps,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Steps',
            hintText: 'One per line',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.nutrition,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _save,
          child: const Text('Save Recipe'),
        ),
      ],
    ),
  );
}
