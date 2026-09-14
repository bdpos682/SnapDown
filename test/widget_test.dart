import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_video/app/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('BDSNAP App boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SnapDownApp(),
      ),
    );

    // Initial pump and settle
    await tester.pump();

    // Verify app brand title
    expect(find.text('BDSNAP'), findsOneWidget);
    // Verify 4 main navigation tabs (100% Pure Vietnamese)
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Tải về'), findsOneWidget);
    expect(find.text('Kho nhạc'), findsOneWidget);
    expect(find.text('Kho video'), findsOneWidget);
  });
}
