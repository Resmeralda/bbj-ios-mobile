import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../models/health_models.dart';
import '../models/nutrition_progress.dart';
import '../models/training_session.dart' show formatDate;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';
import '../data/collection_store.dart';

// ───────────────────── Progress (food log + weight log) ─────────────────────

class NutritionProgressTab extends StatelessWidget {
  const NutritionProgressTab({
    super.key,
    this.weights,
    this.food,
    this.targets,
  });

  final CollectionStore<WeightEntry>? weights;
  final CollectionStore<FoodEntry>? food;
  final NutritionGoalsStore? targets;

  CollectionStore<WeightEntry> get _weights => weights ?? weightStore;
  CollectionStore<FoodEntry> get _food => food ?? foodStore;
  NutritionGoalsStore get _targets => targets ?? goalsStore;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_weights, _targets, _food]),
    builder: (context, _) {
      // ── weight data
      final entries = _weights.items
          .where((entry) => WeightEntry.validPounds(entry.pounds))
          .toList(); // newest first
      final goals = _targets.goals;
      final goal = goals.goalWeight;
      final current = entries.isEmpty ? null : entries.first.pounds;
      final start = entries.isEmpty ? null : entries.last.pounds;

      final progress = weightGoalProgress(start, current, goal);
      final hasWeightGoal = WeightEntry.validPounds(goal);

      final change = (current != null && start != null)
          ? current - start
          : null;
      final recent = entries.take(8).toList().reversed.toList();

      // ── food data
      final foods = _food.items; // newest first
      final now = DateTime.now();
      bool isToday(DateTime date) => DateUtils.isSameDay(date.toLocal(), now);
      final todays = foods.where((f) => isToday(f.date)).toList();
      final todayCal = todays.fold<int>(0, (a, f) => a + f.calories);
      final todayProtein = todays.fold<int>(0, (a, f) => a + f.protein);
      final calProgress = calorieGoalProgress(todayCal, goals.calories);

      final foodTiles = <Widget>[];
      DateTime? lastDay;
      for (final f in foods) {
        final day = DateUtils.dateOnly(f.date.toLocal());
        if (day != lastDay) {
          foodTiles.add(
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                isToday(f.date) ? 'Today' : formatDate(day),
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
            onTap: () => showEditFoodForm(context, f, store: _food),
            onDelete: () async {
              if (await confirmAccountDelete(
                context,
                'food entry',
                () => _food.account,
              )) {
                _food.delete(f.id);
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
                  onPressed: () => showAddFoodForm(context, store: _food),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AddButton(
                  label: 'Log Weight',
                  icon: Icons.monitor_weight_outlined,
                  color: AppColors.nutrition,
                  onPressed: () =>
                      showFormSheet(context, _WeightForm(store: _weights)),
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
                  goals.calories > 0
                      ? '$todayCal / ${goals.calories} cal'
                      : '$todayCal cal',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ProgressBar(calProgress, AppColors.nutrition),
                const SizedBox(height: 4),
                if (goals.calories <= 0)
                  const Text(
                    'No calorie target set',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                Text(
                  '$todayProtein g of ${goals.protein} g protein',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (_food.error != null) EmptyState(_food.error!),
          if (foods.isEmpty && _food.error == null)
            EmptyState(
              _food.loading
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
            StatCard(
              'Goal',
              hasWeightGoal ? '${oneDecimal(goal)} lbs' : 'Not set',
            ),
            StatCard(
              'Change',
              change == null
                  ? '—'
                  : '${change > 0 ? '+' : ''}${oneDecimal(change)} lbs',
              color: const Color(0xFFE6F3E8),
            ),
          ]),
          if (progress != null)
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
                    progress == 1
                        ? '100% • Goal reached'
                        : start == goal
                        ? '${oneDecimal((current! - goal).abs())} lbs '
                              '${current > goal ? 'above' : 'below'} goal'
                        : '${(progress * 100).round()}% of the way from '
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
          if (_weights.error != null) EmptyState(_weights.error!),
          if (entries.isEmpty && _weights.error == null)
            EmptyState(
              _weights.loading
                  ? 'Loading…'
                  : 'No weigh-ins yet. Tap Log Weight to add one.',
            ),
          for (final e in entries)
            EntryTile(
              icon: Icons.monitor_weight_outlined,
              color: AppColors.nutrition,
              title: '${oneDecimal(e.pounds)} lbs',
              subtitle: formatDate(e.date),
              onTap: () => showFormSheet(
                context,
                _WeightForm(store: _weights, existing: e),
              ),
              onDelete: () async {
                if (await confirmAccountDelete(
                  context,
                  'weigh-in',
                  () => _weights.account,
                )) {
                  _weights.delete(e.id);
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 20 + 60 * ((e.pounds - lo) / span),
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
  final CollectionStore<WeightEntry> store;
  final WeightEntry? existing;
  const _WeightForm({required this.store, this.existing});
  @override
  State<_WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<_WeightForm> {
  late final Object _account;
  final _key = GlobalKey<FormState>();
  late final TextEditingController weight;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    _account = widget.store.account;
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
    if (!isCurrentFormAccount(context, _account, widget.store.account)) return;
    if (!_key.currentState!.validate()) return;
    widget.store.save(
      WeightEntry(
        id: widget.existing?.id ?? widget.store.newId(),
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
  final CollectionStore<FoodEntry> store;
  final FoodEntry? existing;
  final String? initialMeal;
  final DateTime? initialDate;
  final Recipe? recipe;

  const _FoodForm({
    required this.store,
    this.existing,
    this.initialMeal,
    this.initialDate,
    this.recipe,
  });

  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  final _key = GlobalKey<FormState>();

  late final TextEditingController name, calories, protein, carbs, fat;
  late DateTime date;
  late String meal;
  late final Object _account;
  late final _entryId = widget.existing?.id ?? widget.store.newId();
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();

    final f = widget.existing;
    final recipe = widget.recipe;
    _account = widget.store.account;

    TextEditingController amount(int? prefilled, int? existing) =>
        TextEditingController(
          text:
              prefilled?.toString() ??
              (existing == null || existing == 0 ? '' : existing.toString()),
        );
    name = TextEditingController(text: f?.name ?? recipe?.name ?? '');
    calories = amount(recipe?.calories, f?.calories);
    protein = amount(recipe?.protein, f?.protein);
    carbs = amount(recipe?.carbs, f?.carbs);
    fat = amount(recipe?.fat, f?.fat);

    // Use the existing entry's date when editing.
    // Otherwise, use the date selected in Food History.
    date = f?.date ?? widget.initialDate ?? DateTime.now();

    final hour = DateTime.now().hour;

    final defaultMeal = hour < 11
        ? 'Breakfast'
        : hour < 15
        ? 'Lunch'
        : hour < 21
        ? 'Dinner'
        : 'Snack';

    // Existing entries take priority when editing.
    // Otherwise, use the selected meal category.
    meal = f?.meal ?? widget.initialMeal ?? defaultMeal;
  }

  @override
  void dispose() {
    name.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving ||
        !isCurrentFormAccount(context, _account, widget.store.account)) {
      return;
    }
    if (!_key.currentState!.validate()) return;
    if (DateUtils.dateOnly(date).isAfter(DateUtils.dateOnly(DateTime.now()))) {
      setState(() => _saveError = 'Choose today or an earlier date.');
      return;
    }

    final entry = FoodEntry(
      id: _entryId,
      date: date,
      meal: meal,
      name: name.text.trim(),
      calories: _enteredAmount(calories),
      protein: _enteredAmount(protein),
      carbs: _enteredAmount(carbs),
      fat: _enteredAmount(fat),
    );

    if (widget.recipe == null) {
      widget.store.save(entry);
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _saving = true;
        _saveError = null;
      });
      try {
        await widget.store.saveConfirmed(entry, account: _account);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _saveError = 'Could not save this food entry. Please try again.';
        });
        return;
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) =>
      AbsorbPointer(absorbing: _saving, child: _buildForm(context));

  Widget _buildForm(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SheetTitle(
                widget.existing == null ? 'Log food' : 'Edit food',
              ),
            ),
            if (widget.existing != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Delete food entry',
                onPressed: () async {
                  final store = widget.store;
                  final id = widget.existing!.id;
                  final confirmed = await confirmAccountDelete(
                    context,
                    'food entry',
                    () => store.account,
                    openedAccount: _account,
                  );
                  if (!confirmed || !context.mounted) return;

                  store.delete(id);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),

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
        TextFormField(
          controller: carbs,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Carbohydrates in g (optional)',
          ),
          validator: optionalNumber,
        ),
        TextFormField(
          controller: fat,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Fat in g (optional)'),
          validator: optionalNumber,
        ),

        DateField(
          date: date,
          lastDate: DateUtils.dateOnly(DateTime.now()),
          onChanged: (d) => setState(() {
            date = d;
            _saveError = null;
          }),
        ),

        if (_saveError case final error?)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),

        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.nutrition,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
        if (widget.recipe != null)
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
      ],
    ),
  );
}

int? _enteredAmount(TextEditingController controller) =>
    double.tryParse(controller.text)?.round();

// ───────────────────────── Goals ─────────────────────────

void showNutritionGoalsForm(
  BuildContext context, {
  NutritionGoalsStore? store,
}) {
  final activeStore = store ?? goalsStore;
  showFormSheet(
    context,
    _GoalsForm(goals: activeStore.goals, store: activeStore),
  );
}

class NutritionGoalsTab extends StatelessWidget {
  const NutritionGoalsTab({super.key, this.store});

  final NutritionGoalsStore? store;

  @override
  Widget build(BuildContext context) {
    final activeStore = store ?? goalsStore;

    return ListenableBuilder(
      listenable: activeStore,
      builder: (context, _) {
        final g = activeStore.goals;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AddButton(
              label: 'Edit Goals',
              icon: Icons.edit,
              color: AppColors.nutrition,
              onPressed: () =>
                  showNutritionGoalsForm(context, store: activeStore),
            ),
            _GoalRow(
              Icons.local_fire_department,
              'Daily calories',
              '${g.calories} cal',
              Colors.deepOrange,
            ),
            _GoalRow(Icons.egg_alt, 'Protein', '${g.protein} g', Colors.blue),
            _GoalRow(
              Icons.grain,
              'Carbs',
              '${g.carbs} g',
              Colors.amber.shade800,
            ),
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
  final NutritionGoalsStore store;

  const _GoalsForm({required this.goals, required this.store});
  @override
  State<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends State<_GoalsForm> {
  late final Object _account;
  final _key = GlobalKey<FormState>();
  late final TextEditingController calories, protein, carbs, fat, water, weight;

  @override
  void initState() {
    super.initState();
    _account = widget.store.account;
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
    if (!isCurrentFormAccount(context, _account, widget.store.account)) return;
    if (!_key.currentState!.validate()) return;
    widget.store.save(
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
  const NutritionRecipesTab({super.key, this.store, this.food});

  final CollectionStore<Recipe>? store;
  final CollectionStore<FoodEntry>? food;

  @override
  Widget build(BuildContext context) {
    final activeStore = store ?? recipeStore;

    return ListenableBuilder(
      listenable: activeStore,
      builder: (context, _) {
        final recipes = activeStore.items;
        final account = activeStore.account;

        bool canUseRecipe() =>
            isCurrentFormAccount(context, account, activeStore.account);

        Future<void> deleteRecipe(Recipe recipe) async {
          if (await confirmAccountDelete(
            context,
            'recipe',
            () => activeStore.account,
            openedAccount: account,
          )) {
            activeStore.delete(recipe.id);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AddButton(
              label: 'Add Recipe',
              color: AppColors.nutrition,
              onPressed: () =>
                  showFormSheet(context, _RecipeForm(store: activeStore)),
            ),
            if (activeStore.error != null) EmptyState(activeStore.error!),
            if (recipes.isEmpty && activeStore.error == null)
              EmptyState(
                activeStore.loading
                    ? 'Loading…'
                    : 'No recipes yet. Tap Add Recipe to save your first one.',
              ),
            for (final r in recipes)
              EntryTile(
                icon: Icons.menu_book,
                color: AppColors.nutrition,
                title: r.name,
                subtitle: _recipeNutrition(r),
                extra: '${r.ingredientList.length} ingredients',
                onTap: () => showFormSheet(
                  context,
                  _RecipeDetail(
                    recipe: r,
                    onAddToFoodLog: () {
                      if (!canUseRecipe()) return;
                      showFormSheet(
                        context,
                        _FoodForm(store: food ?? foodStore, recipe: r),
                      );
                    },
                    onEdit: () {
                      if (!canUseRecipe()) return;
                      showFormSheet(
                        context,
                        _RecipeForm(existing: r, store: activeStore),
                      );
                    },
                    onDelete: () => deleteRecipe(r),
                  ),
                ),
                onDelete: () => deleteRecipe(r),
              ),
          ],
        );
      },
    );
  }
}

String _recipeNutrition(Recipe recipe) {
  final values = [
    if (recipe.calories case final calories?) '$calories cal',
    if (recipe.protein case final protein?) '$protein g protein',
    if (recipe.carbs case final carbs?) '$carbs g carbs',
    if (recipe.fat case final fat?) '$fat g fat',
  ];
  return values.isEmpty ? 'Nutrition not set' : values.join('  •  ');
}

class _RecipeDetail extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onAddToFoodLog, onEdit, onDelete;
  const _RecipeDetail({
    required this.recipe,
    required this.onAddToFoodLog,
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
          _recipeNutrition(recipe),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onAddToFoodLog();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.nutrition),
            icon: const Icon(Icons.add),
            label: const Text('Add to Food Log'),
          ),
        ),
        const SizedBox(height: 8),
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
  final CollectionStore<Recipe> store;

  const _RecipeForm({this.existing, required this.store});
  @override
  State<_RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<_RecipeForm> {
  late final Object _account;
  final _key = GlobalKey<FormState>();
  late final TextEditingController name, calories, protein, ingredients, steps;

  @override
  void initState() {
    super.initState();
    _account = widget.store.account;
    final r = widget.existing;
    name = TextEditingController(text: r?.name ?? '');
    calories = TextEditingController(text: r?.calories?.toString());
    protein = TextEditingController(text: r?.protein?.toString());
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
    if (!isCurrentFormAccount(context, _account, widget.store.account)) return;
    if (!_key.currentState!.validate()) return;

    widget.store.save(
      Recipe(
        id: widget.existing?.id ?? widget.store.newId(),
        name: name.text.trim(),
        calories: _enteredAmount(calories),
        protein: _enteredAmount(protein),
        carbs: widget.existing?.carbs,
        fat: widget.existing?.fat,
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

void showAddFoodForm(
  BuildContext context, {
  String? meal,
  DateTime? date,
  CollectionStore<FoodEntry>? store,
}) {
  showFormSheet(
    context,
    _FoodForm(store: store ?? foodStore, initialMeal: meal, initialDate: date),
  );
}

void showEditFoodForm(
  BuildContext context,
  FoodEntry entry, {
  CollectionStore<FoodEntry>? store,
}) {
  showFormSheet(context, _FoodForm(store: store ?? foodStore, existing: entry));
}
