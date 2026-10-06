import 'package:cosmodrome/services/car/car_bridge.dart';
import 'package:cosmodrome/services/car/car_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carplay/controllers/android_auto_controller.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.oguzhnatly.flutter_android_auto');
const _events = EventChannel('com.oguzhnatly.flutter_android_auto/event');

List<String> _titles(List<dynamic> sections) => [
  for (final section in sections)
    for (final item in (section as Map)['items'] as List)
      (item as Map)['title'] as String,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    FlutterAndroidAutoController.templateHistory.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return true;
    });
    messenger.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  test('More on a root page advances on the first press', () async {
    final bridge = AndroidAutoBridge();
    final page = CarPage(
      id: 'home',
      title: 'Home',
      sections: [
        CarSection(
          header: 'Songs',
          rows: [
            for (var i = 0; i < 10; i++)
              CarRow(title: 'Song $i', onTap: () async {}),
          ],
        ),
      ],
    );
    await bridge.setRoot([page]);

    final root =
        FlutterAndroidAutoController.templateHistory.single as AAListTemplate;
    final more = root.sections
        .expand((s) => s.items)
        .firstWhere((item) => item.title == 'More');

    await more.onPress!(() async {}, more);

    final update = calls.lastWhere(
      (c) => c.method == 'updateListTemplateSections',
    );
    final titles = _titles((update.arguments as Map)['sections'] as List);
    expect(titles.first, 'Previous');
    expect(titles, contains('Song 5'));
    expect(titles, isNot(contains('Song 0')));
  });
}
