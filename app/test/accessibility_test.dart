import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitap_nexus_app/widgets/shadcn/shadcn_ui.dart';
import 'package:vitap_nexus_app/widgets/motion/nexus_motion.dart';

void main() {
  group('Nexus Accessibility & Semantics Unit/Widget Tests', () {
    testWidgets('ShadcnButton outputs proper Semantics label and button role', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShadcnButton(
              label: 'Submit Feedback',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.button == true && widget.properties.label == 'Submit Feedback',
      );

      expect(semanticsFinder, findsOneWidget);

      await tester.tap(find.byType(ShadcnButton));
      expect(pressed, isTrue);
    });

    testWidgets('NexusFilterChip outputs proper selection state and hint in Semantics', (tester) async {
      bool selected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NexusFilterChip(
                  label: 'Fall Semester',
                  isSelected: selected,
                  onTap: () => setState(() => selected = !selected),
                );
              },
            ),
          ),
        ),
      );

      // Verify unselected semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.selected == false && w.properties.label == 'Fall Semester',
        ),
        findsOneWidget,
      );

      // Tap to toggle
      await tester.tap(find.byType(NexusFilterChip));
      await tester.pumpAndSettle();

      // Verify selected semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.selected == true && w.properties.label == 'Fall Semester',
        ),
        findsOneWidget,
      );
    });

    testWidgets('KokonutRollingNumber respects reduced-motion and provides textual value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: KokonutRollingNumber(
                value: 85.5,
                suffix: '%',
                fractionDigits: 1,
              ),
            ),
          ),
        ),
      );

      // When animations disabled, text renders instantly without animation frames
      expect(find.text('85.5%'), findsOneWidget);

      // Semantics should expose exact numeric value to assistive tech
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '85.5%',
        ),
        findsOneWidget,
      );
    });

    testWidgets('BklitGaugeMeter provides descriptive textual equivalent for TalkBack', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BklitGaugeMeter(
              percentage: 82.0,
              targetPercentage: 75.0,
              title: 'Academic Attendance',
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains('Academic Attendance') &&
              w.properties.label!.contains('Safe Zone'),
        ),
        findsOneWidget,
      );
    });
  });
}
