import 'package:cyclesync/app.dart';
import 'package:cyclesync/core/providers.dart';
import 'package:cyclesync/data/services/backend_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({BackendStatus status = BackendStatus.connected}) {
  return ProviderScope(
    overrides: [
      backendStatusProvider.overrideWith((ref) async => status),
      isSignedInProvider.overrideWithValue(false),
    ],
    child: const CycleSyncApp(),
  );
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('phone layout shows bottom navigation and switches tabs',
      (tester) async {
    _setScreen(tester, const Size(400, 800));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Connected securely'), findsOneWidget);
    expect(
      find.text('Add period dates to start receiving estimates.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text('Your logged and estimated period days will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('wide layout uses a navigation rail', (tester) async {
    _setScreen(tester, const Size(1200, 800));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows a retry option when the backend is unreachable',
      (tester) async {
    _setScreen(tester, const Size(400, 800));
    await tester.pumpWidget(_app(status: BackendStatus.couldNotConnect));
    await tester.pumpAndSettle();

    expect(find.text('Could not reach CycleSync servers'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
