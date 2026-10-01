import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => ScreenScaffold(
    title: 'Nutrition',
    color: AppColors.nutrition,
    actionIcon: Icons.settings,
    tabs: const ['Log', 'Progress', 'Goals', 'Recipes'],
    tab: tab,
    onTab: (i) => setState(() => tab = i), // TODO: build other tabs
    children: [
      const AppCard(
        child: Row(
          children: [
            Icon(Icons.chevron_left),
            Expanded(child: Center(child: Text('Tue, Apr 15'))),
            Icon(Icons.calendar_month),
          ],
        ),
      ),
      AppCard(
        child: Row(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: 1420 / 2000,
                      strokeWidth: 12,
                      color: AppColors.nutrition,
                      backgroundColor: Colors.black12,
                    ),
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '1,420',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'of 2,000\ncalories',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                children: [
                  _Macro('Protein', 120, 150, Colors.blue),
                  _Macro('Carbs', 140, 225, Colors.amber),
                  _Macro('Fat', 45, 65, Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
      Row(
        children: [
          QuickTile(Icons.restaurant, 'Breakfast', Colors.red, onTap: () {}),
          QuickTile(
            Icons.restaurant,
            'Lunch',
            Colors.amber.shade800,
            onTap: () {},
          ),
          QuickTile(Icons.restaurant, 'Dinner', Colors.green, onTap: () {}),
          QuickTile(Icons.apple, 'Snack', Colors.deepPurple, onTap: () {}),
        ],
      ),
      const SizedBox(height: 12),
      SectionHeader(
        'Today\'s Meals',
        action: 'Add Food +',
        onAction: () {},
      ), // TODO: food logging flow
      const AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _Meal('Breakfast', 'Overnight oats, banana, protein powder', 380),
            _Meal('Lunch', 'Chicken, rice, broccoli', 450),
            _Meal('Dinner', 'Salmon, sweet potatoes, asparagus', 520),
            _Meal('Snack', 'Greek yogurt, blueberries', 170),
          ],
        ),
      ),
      const AppCard(
        child: Row(
          children: [
            Icon(Icons.water_drop, color: Colors.blue, size: 32),
            SizedBox(width: 12),
            Text('Water Intake', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('64 oz / 80 oz', style: TextStyle(fontSize: 12)),
                  ProgressBar(64 / 80, Colors.lightBlue),
                ],
              ),
            ),
          ],
        ),
      ),
      const Row(
        children: [
          Expanded(
            child: AppCard(
              color: AppColors.tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Weight', style: TextStyle(fontSize: 12)),
                  Text(
                    '165 lbs',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text('Goal: 150 lbs', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: AppCard(
              color: Color(0xFFE6F3E8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Streak', style: TextStyle(fontSize: 12)),
                  Text(
                    '5 days 🔥',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _Macro extends StatelessWidget {
  final String name;
  final int value, target;
  final Color color;
  const _Macro(this.name, this.value, this.target, this.color);

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
        ProgressBar(value / target, color),
      ],
    ),
  );
}

class _Meal extends StatelessWidget {
  final String meal, items;
  final int cal;
  const _Meal(this.meal, this.items, this.cal);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood_outlined),
    ),
    title: Text(meal, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(items, style: const TextStyle(fontSize: 12)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text('$cal cal'), const Icon(Icons.chevron_right)],
    ),
  );
}
