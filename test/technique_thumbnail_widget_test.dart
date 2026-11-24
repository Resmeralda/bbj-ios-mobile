import 'package:bjj_app/models/technique.dart';
import 'package:bjj_app/screens/techniques_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'A failed thumbnail shows its fallback and keeps play available',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TechniqueVideoCard(
              technique: const Technique(
                id: 'armbar',
                name: 'Armbar',
                category: 'Submissions',
                difficulty: 'Beginner',
                description: 'Armbar from guard',
                videoUrl: 'https://youtu.be/abcdefghijk',
              ),
              isFavorite: false,
              onTap: () => opened = true,
              onFavoriteTap: () {},
            ),
          ),
        ),
      );
      final image = find.byType(Image);
      final source = tester.widget<Image>(image).image as NetworkImage;
      expect(source.url, endsWith('/abcdefghijk/hqdefault.jpg'));

      // The widget-test HTTP client returns 400 without a network request.
      final fallback = find.descendant(
        of: image,
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.color == Colors.black87,
        ),
      );
      await tester.pumpAndSettle();
      expect(fallback, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.play_circle));
      expect(opened, isTrue);
    },
  );
}
