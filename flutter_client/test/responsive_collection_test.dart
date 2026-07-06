import 'package:ass_timer_flutter/core/widgets/responsive_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('420x440 window uses a scrollable single-column layout',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(420, 440),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 420,
              height: 440,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ResponsiveCollection(
                  itemCount: 6,
                  itemBuilder: (context, index, singleColumn) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('动作素材 ${index + 1}：已设置自定义照片'),
                          const SizedBox(height: 12),
                          const OutlinedButton(
                            onPressed: null,
                            child: Text('选择照片…'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
