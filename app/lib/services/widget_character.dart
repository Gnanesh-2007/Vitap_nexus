import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_sync_service.dart';

/// Which character the home-screen widgets show.
///
/// `naruto` is the art bundled with the app, `none` is a clean look and
/// `custom` is a picture the user chose (from the gallery or a link). The
/// custom picture is cropped square, shrunk and kept on the phone, where the
/// native widgets read it directly.
/// A bundled character: its id (stored in settings and read by the widgets), its name,
/// and the picture shown in the picker. Every pack has the same four moods, in
/// `assets/images/characters/{id}_{mood}.png` and as `widget_art_{id}_{mood}` on Android.
class CharacterPack {
  final String id;
  final String label;
  final String preview;
  const CharacterPack(this.id, this.label, this.preview);
}

class WidgetCharacter {
  WidgetCharacter._();

  static const packs = [
    CharacterPack('naruto', 'Naruto', 'assets/images/naruto_cool.png'),
    CharacterPack('ds', 'Demon Slayer', 'assets/images/characters/ds_peace.png'),
    CharacterPack('tr', 'Tokyo Revengers', 'assets/images/characters/tr_peace.png'),
  ];

  static const activeKey = 'widget_character_active';
  static String nameOf(File f) => f.path.split(RegExp(r'[\\/]')).last;

  /// Which saved picture is the one in use (null when unknown).
  static Future<String?> activeName() async => (await SharedPreferences.getInstance()).getString(activeKey);

  static const modeKey = 'widget_character_mode';
  static const versionKey = 'widget_character_v';
  static const naruto = 'naruto';
  static const none = 'none';
  static const demonSlayer = 'ds';
  static const tokyoRevengers = 'tr';
  static const custom = 'custom';
  static const tintKey = 'widget_tint';
  static const tintAuto = -1;
  static const glassKey = 'widget_glass';

  static Future<String> mode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(modeKey) ?? naruto;
  }

  static Future<File> customFile() async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory('${dir.path}/widget_art');
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}/custom.png');
  }

  static Future<bool> hasCustom() async => (await customFile()).exists();

  static Future<void> setMode(String m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(modeKey, m);
    await p.setInt(versionKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await WidgetSyncService.update();
  }

  /// Crops to a square, shrinks and stores [bytes]. Returns false if it is not an image.
  static Future<bool> saveCustom(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return false;
    final side = decoded.width < decoded.height ? decoded.width : decoded.height;
    final square = img.copyCrop(
      decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final small = img.copyResize(square, width: 360, height: 360, interpolation: img.Interpolation.cubic);
    final png = img.encodePng(small);
    await (await customFile()).writeAsBytes(png);
    final dir = (await customFile()).parent;
    final saved = File('${dir.path}/lib_${DateTime.now().millisecondsSinceEpoch}.png');
    await saved.writeAsBytes(png);
    await (await SharedPreferences.getInstance()).setString(activeKey, nameOf(saved));
    final all = await library();
    for (final old in all.skip(8)) {
      try {
        await old.delete();
      } catch (_) {}
    }
    await setMode(custom);
    return true;
  }

  /// Saved pictures, newest first.
  static Future<List<File>> library() async {
    final dir = (await customFile()).parent;
    final files = dir.listSync().whereType<File>().where((f) => nameOf(f).startsWith('lib_')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  static Future<void> useFromLibrary(File f) async {
    await f.copy((await customFile()).path);
    await (await SharedPreferences.getInstance()).setString(activeKey, nameOf(f));
    await setMode(custom);
  }

  /// Deletes one saved picture. If it was the one in use, the next saved picture takes over,
  /// and with none left the widgets go back to Naruto. Nothing is left behind on the phone.
  static Future<void> deleteFromLibrary(File f) async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getString(activeKey);
    try {
      await f.delete();
    } catch (_) {}
    final remaining = await library();
    final wasInUse = active == null || active == nameOf(f);
    if (!wasInUse) return;
    if (remaining.isNotEmpty) {
      await useFromLibrary(remaining.first);
      return;
    }
    await _clearCustomFile();
    await prefs.remove(activeKey);
    if ((prefs.getString(modeKey) ?? naruto) == custom) {
      await setMode(naruto);
    } else {
      await WidgetSyncService.update();
    }
  }

  /// Deletes every saved picture and returns to Naruto if one of them was showing.
  static Future<void> removeAllPictures() async {
    for (final f in await library()) {
      try {
        await f.delete();
      } catch (_) {}
    }
    await _clearCustomFile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeKey);
    if ((prefs.getString(modeKey) ?? naruto) == custom) {
      await setMode(naruto);
    } else {
      await WidgetSyncService.update();
    }
  }

  static Future<void> _clearCustomFile() async {
    try {
      final c = await customFile();
      if (await c.exists()) await c.delete();
    } catch (_) {}
  }

  /// 0 = solid cards, 1..100 = glass (higher = more see-through).
  static Future<int> glass() async => (await SharedPreferences.getInstance()).getInt(glassKey) ?? 0;

  static Future<void> setGlass(int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(glassKey, v.clamp(0, 100));
    await p.setInt(versionKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await WidgetSyncService.update();
  }

  /// null = each widget's own colours, [tintAuto] = taken from the picture, else an ARGB colour.
  static Future<int?> tint() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(tintKey);
  }

  static Future<void> setTint(int? v) async {
    final p = await SharedPreferences.getInstance();
    if (v == null) {
      await p.remove(tintKey);
    } else {
      await p.setInt(tintKey, v);
    }
    await p.setInt(versionKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await WidgetSyncService.update();
  }

  static Future<bool> saveFromFile(String path) async => saveCustom(await File(path).readAsBytes());

  /// Downloads an image link (https only, 6 MB max) and uses it.
  static Future<bool> saveFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final out = BytesBuilder(copy: false);
      await for (final chunk in res) {
        out.add(chunk);
        if (out.length > 6 * 1024 * 1024) return false;
      }
      return await saveCustom(out.takeBytes());
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
