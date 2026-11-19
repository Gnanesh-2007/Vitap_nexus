import 'dart:io';

import 'package:flutter/material.dart';

import '../services/widget_character.dart';
import '../utils/today_logic.dart';

/// The user's chosen character (same as on the widgets), shown inside the app.
/// Naruto changes pose with the mood; a custom picture is shown as a round sticker.
class CharacterBadge extends StatefulWidget {
  final DayMood mood;
  final double size;
  const CharacterBadge({super.key, this.mood = DayMood.free, this.size = 96});

  @override
  State<CharacterBadge> createState() => _CharacterBadgeState();
}

class _CharacterBadgeState extends State<CharacterBadge> {
  String _mode = WidgetCharacter.naruto;
  File? _custom;
  int _stamp = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await WidgetCharacter.mode();
      final f = await WidgetCharacter.customFile();
      if (!mounted) return;
      setState(() {
        _mode = m;
        _custom = f.existsSync() ? f : null;
        _stamp = _custom?.lastModifiedSync().millisecondsSinceEpoch ?? 0;
      });
    } catch (_) {}
  }

  /// Naruto has his own poses; the other packs use the same four moods
  /// (fight, run, peace, eye) as round stickers.
  String get _asset {
    if (_mode == WidgetCharacter.demonSlayer || _mode == WidgetCharacter.tokyoRevengers) {
      final mood = switch (widget.mood) {
        DayMood.inClass => 'fight',
        DayMood.soon => 'run',
        _ => 'peace',
      };
      return 'assets/images/characters/${_mode}_$mood.png';
    }
    return switch (widget.mood) {
      DayMood.inClass => 'assets/images/naruto_fight.png',
      DayMood.soon => 'assets/images/naruto_cool.png',
      DayMood.done || DayMood.noClasses => 'assets/images/naruto_success.png',
      DayMood.free => 'assets/images/naruto_cool.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    if (_mode == WidgetCharacter.none) return SizedBox(width: s, height: s);
    if (_mode == WidgetCharacter.custom && _custom != null) {
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: s * 0.04),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: s * 0.15, offset: Offset(0, s * 0.06))],
        ),
        child: ClipOval(child: Image.file(_custom!, fit: BoxFit.cover, key: ValueKey(_stamp))),
      );
    }
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Image.asset(_asset, key: ValueKey(_asset), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox()),
      ),
    );
  }
}
