

import 'package:flutter_test/flutter_test.dart';
import 'package:npl_community/app/app.dart';

void main() {
  testWidgets('NPL Community app launches', (tester) async {
    await tester.pumpWidget(const NplCommunityApp());

    expect(find.text('NPL Community'), findsOneWidget);
  });
}
