import 'package:cyclesync/domain/models.dart';
import 'package:cyclesync/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('signed-out users see the welcome screen', (tester) async {
    _phone(tester);
    await tester.pumpWidget(testApp(FakeRepository(signedIn: false)));
    await tester.pumpAndSettle();

    expect(find.text('CycleSync'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('new users are sent to onboarding', (tester) async {
    _phone(tester);
    final repo = FakeRepository(profile: const Profile(id: 'u1'));
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to CycleSync'), findsOneWidget);
  });

  testWidgets('home shows no estimate without data', (tester) async {
    _phone(tester);
    await tester.pumpWidget(testApp(FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Not enough data yet'), findsOneWidget);
    expect(find.text('Add period dates to start receiving estimates.'),
        findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('home shows countdown from the user setting', (tester) async {
    _phone(tester);
    final repo = FakeRepository(
      profile: const Profile(
        id: 'u1',
        displayName: 'Sarah Johnson',
        onboardingCompleted: true,
        typicalCycleLength: 28,
      ),
      periods: [
        Period(
          id: 'p1',
          start: DateTime.utc(2026, 11, 1),
          end: DateTime.utc(2026, 11, 5),
        ),
      ],
    );
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();

    // 1 Nov + 28 days = 29 Nov, 21 days after 8 Nov.
    expect(find.text('21 days'), findsOneWidget);
    expect(find.text('Cycle day 8'), findsOneWidget);
    expect(find.textContaining('Sarah!'), findsOneWidget);
    expect(find.text('Estimate based on your typical cycle setting'),
        findsOneWidget);
  });

  testWidgets('calendar tab shows the current month', (tester) async {
    _phone(tester);
    await tester.pumpWidget(testApp(FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Period'), findsWidgets);
  });

  testWidgets('saving a daily log stores symptoms and mood', (tester) async {
    _phone(tester);
    final repo = FakeRepository();
    final container = testContainer(repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(testApp(repo, container: container));
    await tester.pumpAndSettle();

    container.read(routerProvider).push(AppRoutes.logFor(testToday));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Calm'));
    await tester.tap(find.text('Calm'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cramps'));
    await tester.tap(find.text('Cramps'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save Entry'));
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    final saved = repo.logs[testToday];
    expect(saved, isNotNull);
    expect(saved!.symptoms, [Symptom.cramps]);
    expect(saved.moods, [Mood.calm]);
  });

  testWidgets('wide screens use a side rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
