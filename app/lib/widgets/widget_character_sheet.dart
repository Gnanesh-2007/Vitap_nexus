import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    final t = await WidgetCharacter.tint();
    final g = await WidgetCharacter.glass();
    if (!mounted) return;
    setState(() {
      _mode = m;
      _custom = f.existsSync() ? f : null;
      _saved = lib;
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

  Future<void> _pickFromGallery() async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    if (picked == null) return;
    await _run(() async => WidgetCharacter.saveCustom(await picked.readAsBytes()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget tile(String id, String label, Widget preview) {
      final on = _mode == id;
      return Expanded(
        child: GestureDetector(
          onTap: () => _choose(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: on ? cs.primary.withValues(alpha: 0.14) : cs.surfaceContainerHigh,
              border: Border.all(color: on ? cs.primary : Colors.transparent, width: 1.6),
            ),
            child: Column(
              children: [
                SizedBox(height: 64, width: 64, child: Center(child: preview)),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
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
        Text('Pick who lives on your home-screen widgets.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(
          children: [
            tile(WidgetCharacter.naruto, 'Naruto', Image.asset('assets/images/naruto_cool.png', fit: BoxFit.contain)),
            const SizedBox(width: 10),
            tile(
              WidgetCharacter.custom,
              'Yours',
              _custom == null
                  ? Icon(Icons.add_photo_alternate_rounded, size: 34, color: cs.onSurfaceVariant)
                  : ClipOval(child: Image.file(_custom!, fit: BoxFit.cover, key: ValueKey(_custom!.lastModifiedSync()))),
            ),
            const SizedBox(width: 10),
            tile(WidgetCharacter.none, 'None', Icon(Icons.block_rounded, size: 34, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 18),
        Text('Any anime you like',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(height: 4),
        Text(
          'Choose a picture of any character from your gallery, or paste an image link. '
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
          Text('Your characters',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 2),
          Text('Tap to switch, long-press to remove.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _saved.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () async {
                  await WidgetCharacter.useFromLibrary(_saved[i]);
                  await _load();
                },
                onLongPress: () async {
                  await WidgetCharacter.deleteFromLibrary(_saved[i]);
                  await _load();
                },
                child: ClipOval(
                  child: Image.file(_saved[i], width: 62, height: 62, fit: BoxFit.cover),
                ),
              ),
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
