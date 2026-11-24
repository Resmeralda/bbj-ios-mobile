import 'package:bjj_app/screens/training_screen.dart';
import 'package:bjj_app/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _labels = ['Gi Class', 'No-Gi Class', 'Open Mat', 'Drilling / Technique'];

Finder _tile(String label) => find.widgetWithText(QuickTile, label);

void main() {
  for (final (width, scale) in [(600.0, 1.0), (280.0, 1.4)]) {
    testWidgets(
      'Training Quick Add tiles align at $width with text scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 950));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = GoRouter(
          initialLocation: '/training',
          routes: [
            GoRoute(
              path: '/training',
              builder: (_, _) => const TrainingScreen(),
              routes: [
                GoRoute(
                  path: 'log',
                  builder: (_, _) => const Scaffold(body: Text('Session form')),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          _tile(_labels.first),
          200,
          scrollable: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        await tester.pumpAndSettle();

        Rect? previous;
        double? iconY;
        double? labelY;
        for (final label in _labels) {
          final tile = _tile(label);
          final surface = tester.getRect(
            find.descendant(of: tile, matching: find.byType(InkWell)),
          );
          final icon = tester.getCenter(
            find.descendant(of: tile, matching: find.byType(Icon)),
          );
          final text = tester.getRect(find.text(label));
          if (previous != null) {
            expect(surface.size, previous.size);
            expect(surface.top, previous.top);
            expect(surface.left - previous.right, closeTo(8, .01));
          }
          expect(icon.dx, closeTo(surface.center.dx, .01));
          expect(text.center.dx, closeTo(surface.center.dx, .01));
          expect(icon.dy, iconY ??= icon.dy);
          expect(text.top, labelY ??= text.top);
          expect(text.bottom, lessThan(surface.bottom));
          previous = surface;
        }

        final drilling = tester.renderObject<RenderParagraph>(
          find.text(_labels.last),
        );
        final lines = drilling
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: _labels.last.length),
            )
            .map((box) => box.top)
            .toSet();
        expect(lines.length, scale == 1 ? 2 : greaterThanOrEqualTo(2));
        expect(tester.takeException(), isNull);

        for (final label in _labels) {
          await tester.ensureVisible(_tile(label));
          await tester.tap(_tile(label));
          await tester.pumpAndSettle();
          expect(find.text('Session form'), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
        }
      },
    );
  }
}
