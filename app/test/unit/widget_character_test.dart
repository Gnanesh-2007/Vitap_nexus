import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitap_nexus_app/services/widget_character.dart';

/// Removing saved pictures must really remove them, and fall back sensibly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  Uint8List picture(int shade) {
    final im = img.Image(width: 40, height: 40);
    img.fill(im, color: img.ColorRgb8(shade, 80, 160));
    return Uint8List.fromList(img.encodePng(im));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('char_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.vitap.vitap_nexus_app/widgets'),
      (call) async => null,
    );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('deleting the picture in use switches to the next one', () async {
    expect(await WidgetCharacter.saveCustom(picture(10)), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(await WidgetCharacter.saveCustom(picture(200)), isTrue);
    var lib = await WidgetCharacter.library();
    expect(lib.length, 2);
    final newest = lib.first;
    expect(await WidgetCharacter.activeName(), WidgetCharacter.nameOf(newest));

    await WidgetCharacter.deleteFromLibrary(newest);
    lib = await WidgetCharacter.library();
    expect(lib.length, 1);
    expect(await WidgetCharacter.activeName(), WidgetCharacter.nameOf(lib.first));
    expect(await WidgetCharacter.mode(), WidgetCharacter.custom);
  });

  test('deleting the last picture removes it from the phone and returns to Naruto', () async {
    await WidgetCharacter.saveCustom(picture(50));
    final only = (await WidgetCharacter.library()).single;
    await WidgetCharacter.deleteFromLibrary(only);
    expect(await WidgetCharacter.library(), isEmpty);
    expect(await (await WidgetCharacter.customFile()).exists(), isFalse);
    expect(await WidgetCharacter.mode(), WidgetCharacter.naruto);
  });

  test('deleting a picture that is not in use keeps the current one', () async {
    await WidgetCharacter.saveCustom(picture(10));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await WidgetCharacter.saveCustom(picture(200));
    final lib = await WidgetCharacter.library();
    final inUse = lib.first;
    await WidgetCharacter.deleteFromLibrary(lib.last);
    expect(await WidgetCharacter.activeName(), WidgetCharacter.nameOf(inUse));
    expect((await WidgetCharacter.library()).length, 1);
  });

  test('remove all clears every picture and the custom file', () async {
    await WidgetCharacter.saveCustom(picture(10));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await WidgetCharacter.saveCustom(picture(90));
    await WidgetCharacter.removeAllPictures();
    expect(await WidgetCharacter.library(), isEmpty);
    expect(await (await WidgetCharacter.customFile()).exists(), isFalse);
    expect(await WidgetCharacter.mode(), WidgetCharacter.naruto);
  });
}
