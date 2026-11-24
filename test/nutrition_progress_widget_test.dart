import 'dart:async';

import 'package:bjj_app/data/collection_store.dart';
import 'package:bjj_app/data/stores.dart';
import 'package:bjj_app/models/health_models.dart';
import 'package:bjj_app/screens/nutrition_screen.dart';
import 'package:bjj_app/widgets/common.dart';
import 'package:bjj_app/widgets/form_helpers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _uid = 'nutrition-athlete';

CollectionStore<T> _store<T>(
  FakeFirebaseFirestore firestore,
  String path,
  T Function(String, Map<String, dynamic>) fromMap,
  Map<String, dynamic> Function(T) toMap,
  String Function(T) id,
  DateTime Function(T) date,
) {
  final store = CollectionStore<T>(
    path: path,
    fromMap: fromMap,
    toMap: toMap,
    idOf: id,
    compare: (a, b) => date(b).compareTo(date(a)),
    firestore: firestore,
  )..bind(_uid);
  addTearDown(store.dispose);
  return store;
}

Future<FakeFirebaseFirestore> _open(
  WidgetTester tester, {
  FakeFirebaseFirestore? database,
  CollectionStore<FoodEntry>? food,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final firestore = database ?? FakeFirebaseFirestore();
  final targets = NutritionGoalsStore(firestore: firestore)..bind(_uid);
  addTearDown(targets.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: NutritionScreen(
        food:
            food ??
            _store(
              firestore,
              'food_log',
              FoodEntry.fromMap,
              (entry) => entry.toMap(),
              (entry) => entry.id,
              (entry) => entry.date,
            ),
        weights: _store(
          firestore,
          'weights',
          WeightEntry.fromMap,
          (entry) => entry.toMap(),
          (entry) => entry.id,
          (entry) => entry.date,
        ),
        targets: targets,
        recipes: _store(
          firestore,
          'recipes',
          Recipe.fromMap,
          (recipe) => recipe.toMap(),
          (recipe) => recipe.id,
          (_) => DateTime(2026),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return firestore;
}

Finder _tab(String label) => find.descendant(
  of: find.byKey(const ValueKey('Nutrition tabs')),
  matching: find.text(label),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<double> _bars(WidgetTester tester) => tester
    .widgetList<ProgressBar>(find.byType(ProgressBar))
    .map((bar) => bar.value)
    .toList();

class _DeferredFoodStore extends CollectionStore<FoodEntry> {
  _DeferredFoodStore(FakeFirebaseFirestore database)
    : super(
        path: 'food_log',
        fromMap: FoodEntry.fromMap,
        toMap: (entry) => entry.toMap(),
        idOf: (entry) => entry.id,
        compare: (a, b) => b.date.compareTo(a.date),
        firestore: database,
      );

  final first = Completer<void>();
  final attempts = <String>[];

  @override
  Future<void> saveConfirmed(FoodEntry item, {required Object account}) async {
    attempts.add(item.id);
    if (attempts.length == 1) await first.future;
    await super.saveConfirmed(item, account: account);
  }
}

void main() {
  testWidgets('Settings opens the same saved Goals editor from every tab', (
    tester,
  ) async {
    final firestore = await _open(tester);
    final calories = find.widgetWithText(TextFormField, 'Daily calories');
    for (final tab in ['Log', 'Progress', 'Goals', 'Recipes']) {
      await _tap(tester, _tab(tab));
      await _tap(tester, find.byIcon(Icons.settings));
      expect(find.text('Nutrition goals'), findsOneWidget);
      final controller = tester.widget<TextFormField>(calories).controller!;
      expect(controller.text, tab == 'Log' ? '2000' : '2400');
      if (tab == 'Log') {
        await tester.enterText(calories, '2400');
        await _tap(tester, find.widgetWithText(FilledButton, 'Save Goals'));
      } else {
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
      }
    }
    expect(
      (await firestore.doc('users/$_uid/settings/nutrition').get())
          .data()!['calories'],
      2400,
    );
  });

  testWidgets(
    'Recipe log reviews recorded values and saves to the chosen date',
    (tester) async {
      final firestore = await _open(tester);
      await firestore.doc('users/$_uid/recipes/bowl').set({
        'name': 'Rice bowl',
        'calories': 450,
        'protein': 0,
        'carbs': 60,
      });
      await _tap(tester, _tab('Recipes'));
      await _tap(tester, find.text('Rice bowl'));
      final add = find.text('Add to Food Log');
      expect(
        tester.getTopLeft(add).dy,
        lessThan(tester.getTopLeft(find.text('Edit')).dy),
      );
      await _tap(tester, add);
      Finder field(String label) => find.widgetWithText(TextFormField, label);
      String value(String label) =>
          tester.widget<TextFormField>(field(label)).controller!.text;
      expect(value('What did you eat?'), 'Rice bowl');
      expect(value('Calories (optional)'), '450');
      expect(value('Protein in g (optional)'), '0');
      expect(value('Carbohydrates in g (optional)'), '60');
      expect(value('Fat in g (optional)'), isEmpty);
      final dateField = tester.widget<DateField>(find.byType(DateField));
      final today = DateUtils.dateOnly(DateTime.now());
      expect(DateUtils.dateOnly(dateField.date), today);
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      dateField.onChanged(yesterday);
      await tester.pump();
      await tester.enterText(field('What did you eat?'), 'Rice bowl serving');
      await _tap(tester, find.widgetWithText(FilledButton, 'Save'));
      final food = await firestore.collection('users/$_uid/food_log').get();
      expect(
        food.docs.single.data(),
        containsPair('date', yesterday.toIso8601String()),
      );
      expect(food.docs.single.data(), containsPair('protein', 0));
      expect(food.docs.single.data(), containsPair('carbs', 60));
      expect(food.docs.single.data(), isNot(contains('fat')));
      await _tap(tester, _tab('Log'));
      expect(find.text('Rice bowl serving'), findsNothing);
      await _tap(tester, find.byIcon(Icons.chevron_left));
      expect(find.text('Rice bowl serving'), findsOneWidget);
    },
  );

  testWidgets(
    'Recipe log retains a failed draft and a repeated tap writes once',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final store = _DeferredFoodStore(firestore)..bind(_uid);
      addTearDown(store.dispose);
      await firestore.doc('users/$_uid/recipes/soup').set({'name': 'Soup'});
      await _open(tester, database: firestore, food: store);
      await _tap(tester, _tab('Recipes'));
      expect(find.text('Nutrition not set'), findsOneWidget);
      await _tap(tester, find.text('Soup'));
      await _tap(tester, find.text('Add to Food Log'));
      await _tap(tester, find.widgetWithText(TextButton, 'Cancel'));
      expect(find.text('Log food'), findsNothing);
      await _tap(tester, find.text('Soup'));
      await _tap(tester, find.text('Add to Food Log'));
      final calories = find.widgetWithText(
        TextFormField,
        'Calories (optional)',
      );
      expect(tester.widget<TextFormField>(calories).controller!.text, isEmpty);
      await tester.enterText(calories, '320');
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Dinner'));
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(store.attempts, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      store.first.completeError(StateError('Simulated write failure'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save this food entry. Please try again.'),
        findsOneWidget,
      );
      expect(tester.widget<TextFormField>(calories).controller!.text, '320');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dinner'))
            .selected,
        isTrue,
      );
      await _tap(tester, save);
      expect(store.attempts, [store.attempts.first, store.attempts.first]);
      final food = await firestore.collection('users/$_uid/food_log').get();
      expect(food.docs.single.data(), containsPair('calories', 320));
      expect(food.docs.single.data(), isNot(contains('protein')));
      await _tap(tester, _tab('Log'));
      expect(find.text('Soup'), findsOneWidget);
      await _tap(tester, _tab('Progress'));
      expect(find.text('320 / 2000 cal'), findsOneWidget);
    },
  );

  testWidgets(
    'Calorie displays keep actual totals and distinguish dates and invalid targets',
    (tester) async {
      final firestore = await _open(tester);
      final today = DateUtils.dateOnly(DateTime.now());
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final goals = firestore.doc('users/$_uid/settings/nutrition');
      final food = firestore.collection('users/$_uid/food_log');
      await _tap(tester, _tab('Progress'));
      expect(find.text('0 / 2000 cal'), findsOneWidget);
      expect(
        find.text('Nothing logged yet. Tap Log Food to add what you ate.'),
        findsOneWidget,
      );
      expect(_bars(tester), [0]);
      await food.doc('today').set({
        'date': today.toUtc().toIso8601String(),
        'name': 'Today meal',
        'calories': 2800,
      });
      await food.doc('yesterday').set({
        'date': yesterday.toIso8601String(),
        'name': 'Earlier meal',
        'calories': 600,
      });
      await tester.pumpAndSettle();
      expect(find.text('2800 / 2000 cal'), findsOneWidget);
      expect(_bars(tester), [1]);
      await _tap(tester, _tab('Log'));
      double? ring() => tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value;
      expect(find.text('2800'), findsOneWidget);
      expect(ring(), 1);
      await _tap(tester, find.byIcon(Icons.chevron_left));
      expect(find.text('600'), findsOneWidget);
      expect(ring(), .3);
      await goals.set({'calories': 1200});
      await tester.pumpAndSettle();
      expect(ring(), .5);
      await goals.set({'calories': double.nan});
      await tester.pumpAndSettle();
      expect(find.text('calories\nNo target set'), findsOneWidget);
      expect(find.text('600'), findsOneWidget);
      expect(ring(), 0);
      await _tap(tester, _tab('Progress'));
      expect(find.text('2800 cal'), findsWidgets);
      expect(find.text('No calorie target set'), findsOneWidget);
      expect(_bars(tester), [0]);
      await food.doc('today').update({'calories': 500});
      await goals.set({'calories': 1000});
      await tester.pumpAndSettle();
      expect(find.text('500 / 1000 cal'), findsOneWidget);
      expect(_bars(tester), [.5]);
      await food.doc('today').delete();
      await tester.pumpAndSettle();
      expect(find.text('0 / 1000 cal'), findsOneWidget);
      expect(_bars(tester), [0]);
    },
  );

  testWidgets(
    'Weight progress updates for both directions and an equal starting target',
    (tester) async {
      final firestore = await _open(tester);
      final goals = firestore.doc('users/$_uid/settings/nutrition');
      final weights = firestore.collection('users/$_uid/weights');
      final start = weights.doc('start');
      final latest = weights.doc('latest');
      await goals.set({'goalWeight': 180});
      await _tap(tester, _tab('Progress'));
      expect(
        find.text('No weigh-ins yet. Tap Log Weight to add one.'),
        findsOneWidget,
      );
      expect(find.text('Progress to goal'), findsNothing);

      await start.set({'date': '2026-01-01', 'pounds': 200});
      await latest.set({'date': '2026-01-02', 'pounds': 190});
      await tester.pumpAndSettle();
      expect(
        find.text('50% of the way from 200.0 to 180.0 lbs'),
        findsOneWidget,
      );
      expect(_bars(tester), [0, .5]);
      await latest.update({'pounds': 179});
      await tester.pumpAndSettle();
      expect(find.text('100% • Goal reached'), findsOneWidget);
      expect(_bars(tester), [0, 1]);

      await start.update({'pounds': 140});
      await latest.update({'pounds': 150});
      await goals.update({'goalWeight': 160});
      await tester.pumpAndSettle();
      expect(
        find.text('50% of the way from 140.0 to 160.0 lbs'),
        findsOneWidget,
      );
      await latest.update({'pounds': 162});
      await tester.pumpAndSettle();
      expect(find.text('100% • Goal reached'), findsOneWidget);
      expect(_bars(tester), [0, 1]);

      await goals.update({'goalWeight': 140});
      await tester.pumpAndSettle();
      expect(find.text('22.0 lbs above goal'), findsOneWidget);
      expect(_bars(tester), [0, 0]);
      await latest.update({'pounds': 138});
      await tester.pumpAndSettle();
      expect(find.text('2.0 lbs below goal'), findsOneWidget);
      await latest.update({'pounds': 140});
      await tester.pumpAndSettle();
      expect(find.text('100% • Goal reached'), findsOneWidget);
      expect(_bars(tester), [0, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Weight chart omits invalid readings and safely plots valid ones',
    (tester) async {
      final firestore = await _open(tester);
      final weights = firestore.collection('users/$_uid/weights');
      await firestore.doc('users/$_uid/settings/nutrition').set({
        'goalWeight': double.infinity,
      });
      for (final (index, pounds) in [
        double.nan,
        double.infinity,
        -12,
        0,
        'bad',
      ].indexed) {
        await weights.doc('bad-$index').set({
          'date': '2026-02-01',
          'pounds': pounds,
        });
      }
      await weights.doc('bad-date').set({'date': 'invalid', 'pounds': 300});
      await _tap(tester, _tab('Progress'));
      expect(find.text('Not set'), findsOneWidget);
      expect(find.byType(EntryTile), findsNothing);
      expect(
        find.text('No weigh-ins yet. Tap Log Weight to add one.'),
        findsOneWidget,
      );
      await weights.doc('start').set({'date': '2026-01-02', 'pounds': 155});
      await weights.doc('latest').set({'date': '2026-01-03', 'pounds': 1e307});
      await tester.pumpAndSettle();
      expect(find.byType(EntryTile), findsNWidgets(2));
      expect(find.text('155.0'), findsOneWidget);
      expect(find.text('1e+307'), findsOneWidget);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(find.textContaining('NaN'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Nutrition forms reject non-finite input and retain existing save and delete flows',
    (tester) async {
      final firestore = await _open(tester);
      final food = firestore.collection('users/$_uid/food_log');
      final weights = firestore.collection('users/$_uid/weights');
      final save = find.widgetWithText(FilledButton, 'Save');
      Finder field(String label) => find.widgetWithText(TextFormField, label);

      await _tap(tester, find.byIcon(Icons.chevron_left));
      for (final meal in mealTypes) {
        await _tap(tester, find.widgetWithText(QuickTile, meal));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, meal))
              .selected,
          isTrue,
        );
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
      }
      await _tap(tester, find.text('Add Food +'));
      await tester.enterText(field('What did you eat?'), 'Rice bowl');
      final calorieInput = field('Calories (optional)');
      await tester.enterText(calorieInput, 'NaN');
      await _tap(tester, save);
      expect(find.text('Enter a valid number'), findsOneWidget);
      expect((await food.get()).docs, isEmpty);
      await tester.enterText(calorieInput, '300');
      await _tap(tester, save);
      expect(find.text('300'), findsOneWidget);
      await _tap(tester, find.text('Rice bowl'));
      expect(find.text('Edit food'), findsOneWidget);
      await tester.enterText(calorieInput, '350');
      await _tap(tester, save);
      expect(find.text('350'), findsOneWidget);
      await tester.longPress(find.text('Rice bowl'));
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
      expect((await food.get()).docs, isEmpty);

      await _tap(tester, _tab('Progress'));
      await _tap(tester, find.text('Log Food'));
      await tester.enterText(field('What did you eat?'), 'Oatmeal');
      await tester.enterText(calorieInput, '420');
      await _tap(tester, save);
      expect(find.text('420 / 2000 cal'), findsOneWidget);
      await _tap(tester, find.text('Oatmeal'));
      expect(find.text('Edit food'), findsOneWidget);
      await _tap(tester, find.byTooltip('Delete food entry'));
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
      expect(find.text('0 / 2000 cal'), findsOneWidget);

      await _tap(tester, find.text('Log Weight'));
      final weight = field('Weight (lbs)');
      await tester.enterText(weight, 'Infinity');
      await _tap(tester, save);
      expect(find.text('Enter a number above 0'), findsOneWidget);
      expect((await weights.get()).docs, isEmpty);
      await tester.enterText(weight, '180');
      await _tap(tester, save);
      await _tap(tester, find.widgetWithText(EntryTile, '180.0 lbs'));
      expect(find.text('Edit weight'), findsOneWidget);
      await tester.enterText(weight, '182');
      await _tap(tester, save);
      expect((await weights.get()).docs.single.data()['pounds'], 182);
      await _tap(tester, find.byIcon(Icons.delete_outline));
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
      expect((await weights.get()).docs, isEmpty);
      expect(
        find.text('No weigh-ins yet. Tap Log Weight to add one.'),
        findsOneWidget,
      );

      await _tap(tester, _tab('Goals'));
      expect(find.text('80 oz'), findsOneWidget);
      await _tap(tester, find.text('Edit Goals'));
      await tester.enterText(field('Goal weight (lbs, optional)'), 'NaN');
      await _tap(tester, find.widgetWithText(FilledButton, 'Save Goals'));
      expect(find.text('Enter a valid number'), findsOneWidget);
      expect(
        (await firestore.doc('users/$_uid/settings/nutrition').get()).exists,
        isFalse,
      );
    },
  );
}
