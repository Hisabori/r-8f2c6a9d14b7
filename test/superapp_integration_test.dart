import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/main.dart';
import 'package:bark_note/native_modules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native bridge passes a module identifier only', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeModules.channel, (call) async {
          calls.add(call);
          return true;
        });
    final old = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(await NativeModules.open('crypto'), isTrue);
      expect(calls.single.method, 'open');
      expect(calls.single.arguments, {'module': 'crypto'});
      await expectLater(
        NativeModules.open('arbitrary-url'),
        throwsArgumentError,
      );
      expect(calls.length, 1);
    } finally {
      debugDefaultTargetPlatformOverride = old;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeModules.channel, null);
    }
  });
  testWidgets('super home exposes three app modules and preserves transit', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeModules.channel, (call) async {
          calls.add(call);
          return true;
        });
    final old = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(const MaterialApp(home: FeatureHome()));
      await tester.pump();
      for (final name in ['오늘', '온케어', '강아지', '투자', '이동']) {
        expect(find.text(name), findsWidgets);
      }
      await tester.tap(find.text('온케어').last);
      await tester.pump();
      expect(calls.last.arguments, {'module': 'health'});
      await tester.tap(find.text('투자').last);
      await tester.pump();
      expect(calls.last.arguments, {'module': 'crypto'});
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = old;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeModules.channel, null);
    }
  });
}
