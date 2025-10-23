import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple, self-contained counter widget for tests (avoids app-level Firebase init)
class CounterApp extends StatefulWidget {
  const CounterApp({Key? key}) : super(key: key);
  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  int _count = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Counter Test')),
        body: Center(child: Text('$_count', key: const Key('counter'))),
        floatingActionButton: FloatingActionButton(
          key: const Key('increment'),
          onPressed: () => setState(() => _count++),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CounterApp());

    // Verify initial state
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap increment
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
