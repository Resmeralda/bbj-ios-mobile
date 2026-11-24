import 'package:bjj_app/theme.dart';
import 'package:bjj_app/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const sections = [
  (
    'Recovery',
    AppColors.recovery,
    ['Overview', 'Sleep', 'Wellness', 'Notes', 'Mobility'],
  ),
  ('Training', AppColors.training, ['Log', 'History', 'Techniques']),
  ('Nutrition', AppColors.nutrition, ['Log', 'Progress', 'Goals', 'Recipes']),
];

Future<void> _pumpSection(
  WidgetTester tester,
  String title,
  Color color,
  List<String> tabs, {
  required double width,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  var selected = 0;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: StatefulBuilder(
        builder: (context, setState) => ScreenScaffold(
          title: title,
          color: color,
          responsiveTabs: true,
          tabs: tabs,
          tab: selected,
          onTab: (value) => setState(() => selected = value),
          children: [Text('Showing ${tabs[selected]}')],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (title, color, tabs) in sections) {
    Finder strip() => find.byKey(ValueKey('$title tabs'));
    Finder button(String label) => find.descendant(
      of: strip(),
      matching: find.widgetWithText(InkWell, label),
    );
    Finder scrollView() => find.descendant(
      of: strip(),
      matching: find.byType(SingleChildScrollView),
    );

    testWidgets('$title distributes all tabs across one row at normal width', (
      tester,
    ) async {
      await _pumpSection(tester, title, color, tabs, width: 800);
      final rects = tabs.map((label) => tester.getRect(button(label))).toList();
      expect(scrollView(), findsNothing);
      for (final rect in rects) {
        expect(rect.top, rects.first.top);
        expect(rect.width, closeTo(rects.first.width, .01));
        expect(rect.height, rects.first.height);
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left - rects[i - 1].right, closeTo(4, .01));
      }
      final bounds = tester.getRect(strip());
      expect(rects.first.left, closeTo(bounds.left, .01));
      expect(rects.last.right, closeTo(bounds.right, .01));

      await tester.tap(button(tabs.last));
      await tester.pumpAndSettle();
      expect(find.text('Showing ${tabs.last}'), findsOneWidget);
      Color? tabColor(String label) => tester
          .widget<Material>(
            find
                .ancestor(of: button(label), matching: find.byType(Material))
                .first,
          )
          .color;
      expect(tabColor(tabs.last), Colors.white);
      expect(tabColor(tabs.first), Colors.black26);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$title scrolls a single equal-width row with large text', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        title,
        color,
        tabs,
        width: 240,
        textScale: 1.4,
      );
      expect(scrollView(), findsOneWidget);
      final first = tester.getRect(button(tabs.first));
      for (final label in tabs) {
        final rect = tester.getRect(button(label));
        expect(rect.top, first.top);
        expect(rect.size, first.size);
      }
      await tester.drag(scrollView(), const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(button(tabs.last).hitTestable(), findsOneWidget);
      await tester.tap(button(tabs.last));
      await tester.pumpAndSettle();
      expect(find.text('Showing ${tabs.last}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
