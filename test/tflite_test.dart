import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite/tflite.dart';

void main() {
  const MethodChannel channel = MethodChannel('tflite');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await Tflite.platformVersion, '42');
  });
}
