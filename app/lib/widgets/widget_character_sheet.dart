import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/widget_character.dart';
import 'sheet_kit.dart';

/// "Widget character": pick what the home-screen widgets show.
Future<void> showWidgetCharacterSheet(BuildContext context) {
  return showNexusSheet<void>(context, (_) => const _CharacterPicker());
}

class _CharacterPicker extends StatefulWidget {
  const _CharacterPicker();

  @override
  State<_CharacterPicker> createState() => _CharacterPickerState();
}

class _CharacterPickerState extends State<_CharacterPicker> {
  String _mode = WidgetCharacter.naruto;
  File? _custom;
  List<File> _saved = [];
  List<CharacterPack> _packs = [WidgetCharacter.packs.first];
  String? _active;
  int? _tint;
  int _glass = 0;
  bool _busy = false;
  final _url = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = await WidgetCharacter.mode();
    final f = await WidgetCharacter.customFile();
    final lib = await WidgetCharacter.library();
    final active = await WidgetCharacter.activeName();
    final packs = await _availablePacks();
    final t = await WidgetCharacter.tint();
    final g = await WidgetCharacter.glass();
    if (!mounted) return;
    setState(() {
      _mode = m;
      _custom = f.existsSync() ? f : null;
      _saved = lib;
      _active = active;
      _packs = packs;
      _tint = t;
      _glass = g;
    });
  }

  Future<void> _choose(String mode) async {
    await WidgetCharacter.setMode(mode);
    if (mounted) setState(() => _mode = mode);
  }

  Future<void> _run(Future<bool> Function() job) async {
    setState(() => _busy = true);
    final ok = await job();
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    nexusToast(context, ok ? 'Widgets updated' : "Couldn't use that image");
  }

  /// Only characters whose pictures are actually in this build are offered, so a copy of the
  /// project without the sticker packs simply shows Naruto, your own pictures and None.
  Future<List<CharacterPack>> _availablePacks() async {
    final out = <CharacterPack>[];
    for (final p in WidgetCharacter.packs) {
      try {
        await rootBundle.load(p.preview);
        out.add(p);
      } catch (_) {}
    }
    return out.isEmpty ? [WidgetCharacter.packs.first] : out;
  }

  Future<void> _delete(File f) async {
    await WidgetCharacter.deleteFromLibrary(f);
    await _load();
    if (mounted) nexusToast(context, 'Picture removed');
  }

  Future<void> _removeAll() async {
    await WidgetCharacter.removeAllPictures();
    await _load();
    if (mounted) nexusToast(context, 'All pictures removed');
  }

  Future<void> _pickFromGallery() async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    if (picked == null) return;
    await _run(() async => WidgetCharacter.saveCustom(await picked.readAsBytes()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tileW = (MediaQuery.sizeOf(context).width - 44 - 20) / 3;
    Widget tile(String id, String label, Widget preview) {
      final on = _mode == id;
      return SizedBox(
        width: tileW,
        child: GestureDetector(
          onTap: () => _choose(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: on ? cs.primary.withValues(alpha: 0.14) : cs.surfaceContainerHigh,
              border: Border.all(color: on ? cs.primary : Colors.transparent, width: 1.6),
            ),
            child: Column(
              children: [
                SizedBox(height: 62, width: 62, child: Center(child: preview)),
                const SizedBox(height: 8),
                Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.15, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Widget character',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(height: 4),
        Text('Pick who shows on your home screen and widgets. Each one changes with your day: focused in class, panicking when you are late, relaxed when you are free.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in _packs)
              tile(p.id, p.label, Image.asset(p.preview, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox())),
            tile(
              WidgetCharacter.custom,
              'Yours',
              _custom == null
                  ? Icon(Icons.add_photo_alternate_rounded, size: 32, color: cs.onSurfaceVariant)
                  : ClipOval(child: Image.file(_custom!, fit: BoxFit.cover, key: ValueKey('${_custom!.path}$_active'))),
            ),
            tile(WidgetCharacter.none, 'None', Icon(Icons.block_rounded, size: 32, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 18),
        Text('Use your own picture',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(height: 4),
        Text(
          'Choose any picture from your gallery, or paste an image link. '
          'It is cropped to a round sticker and stays on your phone.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        NexusButton(
          label: _busy ? 'Working…' : 'Choose from gallery',
          icon: Icons.photo_library_rounded,
          filled: true,
          onTap: _busy ? null : _pickFromGallery,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://…  image link',
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            NexusButton(
              label: 'Use',
              dense: true,
              onTap: _busy ? null : () => _run(() => WidgetCharacter.saveFromUrl(_url.text)),
            ),
          ],
        ),
        if (_saved.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Your pictures',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
              ),
              TextButton(
                onPressed: _busy ? null : _removeAll,
                style: TextButton.styleFrom(foregroundColor: cs.error, visualDensity: VisualDensity.compact),
                child: const Text('Remove all'),
              ),
            ],
          ),
          Text('Tap one to use it. Tap the cross to delete it.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _saved.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final f = _saved[i];
                final isActive = _mode == WidgetCharacter.custom && WidgetCharacter.nameOf(f) == _active;
                return SizedBox(
                  width: 70,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await WidgetCharacter.useFromLibrary(f);
                          await _load();
                        },
                        child: Container(
                          width: 66,
                          height: 66,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isActive ? cs.primary : Colors.transparent, width: 2.5),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipOval(child: Image.file(f, fit: BoxFit.cover)),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        top: -4,
                        child: GestureDetector(
                          onTap: () => _delete(f),
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cs.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                            child: Icon(Icons.close_rounded, size: 17, color: cs.onError),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Glass widgets',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
                  Text('See-through and glossy, your wallpaper shows behind.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Switch.adaptive(
              value: _glass > 0,
              onChanged: (on) async {
                await WidgetCharacter.setGlass(on ? 50 : 0);
                await _load();
              },
            ),
          ],
        ),
        if (_glass > 0)
          Slider(
            value: _glass.toDouble(),
            min: 10,
            max: 100,
            divisions: 9,
            label: '$_glass%',
            onChanged: (v) => setState(() => _glass = v.round()),
            onChangeEnd: (v) => WidgetCharacter.setGlass(v.round()),
          ),
        const SizedBox(height: 18),
        Text('Widget colours',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _swatch(cs, null, Icons.auto_awesome_mosaic_rounded, 'Default'),
            _swatch(cs, WidgetCharacter.tintAuto, Icons.colorize_rounded, 'From picture'),
            for (final c in _presets) _swatch(cs, c, null, ''),
          ],
        ),
      ],
    );
  }

  static const _presets = [0xFFFF7A1A, 0xFF2F6BFF, 0xFF8B3DFF, 0xFFE02B3A, 0xFF1FA85A, 0xFFFF4D9D];

  Widget _swatch(ColorScheme cs, int? value, IconData? icon, String label) {
    final on = _tint == value;
    final color = value == null || value == WidgetCharacter.tintAuto ? cs.surfaceContainerHigh : Color(value);
    final chip = GestureDetector(
      onTap: () async {
        await WidgetCharacter.setTint(value);
        await _load();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: on ? cs.onSurface : Colors.transparent, width: 2.4),
        ),
        child: icon == null ? null : Icon(icon, size: 20, color: cs.onSurfaceVariant),
      ),
    );
    if (label.isEmpty) return chip;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      chip,
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
    ]);
  }
}
