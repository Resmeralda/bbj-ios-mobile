import 'package:flutter/material.dart';

import '../data/collection_store.dart';
import '../data/stores.dart';
import '../models/health_models.dart';
import '../models/nutrition_progress.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';
import 'nutrition_tabs.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({
    super.key,
    this.weights,
    this.food,
    this.targets,
    this.recipes,
  });

  final CollectionStore<WeightEntry>? weights;
  final CollectionStore<FoodEntry>? food;
  final NutritionGoalsStore? targets;
  final CollectionStore<Recipe>? recipes;

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int tab = 0;
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

  CollectionStore<FoodEntry> get _food => widget.food ?? foodStore;
  NutritionGoalsStore get _targets => widget.targets ?? goalsStore;

  bool isSameDay(DateTime a, DateTime b) =>
      DateUtils.isSameDay(a.toLocal(), b.toLocal());

  bool get isToday => isSameDay(selectedDate, DateTime.now());

  void changeDay(int days) {
    final next = DateUtils.dateOnly(selectedDate.add(Duration(days: days)));

    if (next.isAfter(DateUtils.dateOnly(DateTime.now()))) return;

    setState(() => selectedDate = next);
  }

  Future<void> selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null && mounted) {
      setState(() => selectedDate = date);
    }
  }

  String get mealsHeading {
    if (isToday) return "Today's Meals";

    final yesterday = DateUtils.dateOnly(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    if (isSameDay(selectedDate, yesterday)) {
      return "Yesterday's Meals";
    }

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return "${weekdays[selectedDate.weekday - 1]}'s Meals";
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
    title: 'Nutrition',
    color: AppColors.nutrition,
    actionIcon: Icons.settings,
    onAction: () => showNutritionGoalsForm(context, store: _targets),
    tabs: const ['Log', 'Progress', 'Goals', 'Recipes'],
    responsiveTabs: true,
    tab: tab,
    onTab: (i) => setState(() => tab = i),
    children: tab == 1
        ? [
            NutritionProgressTab(
              weights: widget.weights,
              food: _food,
              targets: _targets,
            ),
          ]
        : tab == 2
        ? [NutritionGoalsTab(store: _targets)]
        : tab == 3
        ? [NutritionRecipesTab(store: widget.recipes, food: _food)]
        : [
            ListenableBuilder(
              listenable: Listenable.merge([_food, _targets]),
              builder: (context, _) {
                final foods = _food.items
                    .where((f) => isSameDay(f.date, selectedDate))
                    .toList();

                final calories = foods.fold<int>(
                  0,
                  (sum, f) => sum + f.calories,
                );

                final protein = foods.fold<int>(0, (sum, f) => sum + f.protein);
                final carbs = foods.fold<int>(0, (sum, f) => sum + f.carbs);

                final fat = foods.fold<int>(0, (sum, f) => sum + f.fat);

                final goals = _targets.goals;
                final calorieGoal = goals.calories;
                final proteinGoal = goals.protein;
                final carbsGoal = goals.carbs;
                final fatGoal = goals.fat;

                final calorieProgress = calorieGoalProgress(
                  calories,
                  calorieGoal,
                );

                final proteinProgress = proteinGoal > 0
                    ? (protein / proteinGoal).clamp(0.0, 1.0).toDouble()
                    : 0.0;

                final carbsProgress = carbsGoal > 0
                    ? (carbs / carbsGoal).clamp(0.0, 1.0).toDouble()
                    : 0.0;

                final fatProgress = fatGoal > 0
                    ? (fat / fatGoal).clamp(0.0, 1.0).toDouble()
                    : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date navigation
                    AppCard(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => changeDay(-1),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: isToday ? null : () => changeDay(1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: selectDate,
                          ),
                        ],
                      ),
                    ),

                    // Circular calorie tracker
                    AppCard(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: calorieProgress,
                                    strokeWidth: 12,
                                    color: AppColors.nutrition,
                                    backgroundColor: Colors.black12,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$calories',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      calorieGoal > 0
                                          ? 'of $calorieGoal\ncalories'
                                          : 'calories\nNo target set',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                _MacroProgress(
                                  'Protein',
                                  protein,
                                  proteinGoal,
                                  proteinProgress,
                                  Colors.blue,
                                ),
                                _MacroProgress(
                                  'Carbs',
                                  carbs,
                                  carbsGoal,
                                  carbsProgress,
                                  Colors.amber,
                                ),
                                _MacroProgress(
                                  'Fat',
                                  fat,
                                  fatGoal,
                                  fatProgress,
                                  Colors.purple,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Meal category shortcuts
                    Row(
                      children: [
                        QuickTile(
                          Icons.restaurant,
                          'Breakfast',
                          Colors.red,
                          onTap: () => showAddFoodForm(
                            context,
                            meal: 'Breakfast',
                            date: selectedDate,
                            store: _food,
                          ),
                        ),
                        QuickTile(
                          Icons.restaurant,
                          'Lunch',
                          Colors.orange,
                          onTap: () => showAddFoodForm(
                            context,
                            meal: 'Lunch',
                            date: selectedDate,
                            store: _food,
                          ),
                        ),
                        QuickTile(
                          Icons.restaurant,
                          'Dinner',
                          Colors.green,
                          onTap: () => showAddFoodForm(
                            context,
                            meal: 'Dinner',
                            date: selectedDate,
                            store: _food,
                          ),
                        ),
                        QuickTile(
                          Icons.apple,
                          'Snack',
                          Colors.deepPurple,
                          onTap: () => showAddFoodForm(
                            context,
                            meal: 'Snack',
                            date: selectedDate,
                            store: _food,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SectionHeader(
                      mealsHeading,
                      action: 'Add Food +',
                      onAction: () => showAddFoodForm(
                        context,
                        date: selectedDate,
                        store: _food,
                      ),
                    ),

                    if (_food.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_food.error != null)
                      EmptyState(_food.error!)
                    else if (foods.isEmpty)
                      const AppCard(
                        child: Text('No meals logged for this day.'),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final meal in mealTypes)
                              for (final food in foods.where(
                                (f) => f.meal == meal,
                              ))
                                ListTile(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.fastfood_outlined),
                                  ),
                                  title: Text(
                                    food.meal,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(food.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${food.calories} cal'),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () => showEditFoodForm(
                                    context,
                                    food,
                                    store: _food,
                                  ),
                                  onLongPress: () async {
                                    if (await confirmDelete(
                                      context,
                                      'food entry',
                                    )) {
                                      _food.delete(food.id);
                                    }
                                  },
                                ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
  );
}

class _MacroProgress extends StatelessWidget {
  final String name;
  final int value;
  final int target;
  final double progress;
  final Color color;

  const _MacroProgress(
    this.name,
    this.value,
    this.target,
    this.progress,
    this.color,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 6),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$value g / $target g', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ProgressBar(progress, color),
      ],
    ),
  );
}
