import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/reminder_service.dart';
import 'nexus_segmented.dart';
import 'sheet_kit.dart';

/// Profile → Reminders: the user decides whether to get notifications and for what.
Future<void> showRemindersSheet(BuildContext context) {
  return showNexusSheet<void>(context, (_) => const _RemindersPanel());
}

class _RemindersPanel extends StatefulWidget {
  const _RemindersPanel();

  @override
  State<_RemindersPanel> createState() => _RemindersPanelState();
}

class _RemindersPanelState extends State<_RemindersPanel> {
  bool _on = false;
  int _minutes = 15;
  bool _exams = true;
  bool _blocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await ReminderService.enabled();
    final m = await ReminderService.classMinutes();
    final e = await ReminderService.exams();
    if (!mounted) return;
    setState(() {
      _on = on;
      _minutes = ReminderService.classMinuteChoices.contains(m) ? m : 15;
      _exams = e;
    });
  }

  Future<void> _toggle(bool want) async {
    setState(() => _busy = true);
    final now = await ReminderService.setEnabled(want);
    if (!mounted) return;
    setState(() {
      _on = now;
      _blocked = want && !now;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final choices = ReminderService.classMinuteChoices;
    final index = choices.indexOf(_minutes).clamp(0, choices.length - 1);

    Widget heading(String text) => Text(text,
        style: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface));
    Widget note(String text) =>
        Text(text, style: GoogleFonts.dmSans(fontSize: 12.5, height: 1.35, color: cs.onSurfaceVariant));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reminders',
            style: GoogleFonts.bricolageGrotesque(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: cs.onSurface)),
        const SizedBox(height: 4),
        note('Notifications from your phone before classes and exams. Nothing is sent anywhere, and they are off unless you turn them on.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: heading('Turn on reminders')),
            Switch.adaptive(value: _on, onChanged: _busy ? null : _toggle),
          ],
        ),
        if (_blocked) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
            child: Text(
              'Notifications are blocked for this app. Allow them in your phone\'s settings (Apps, VITAP Nexus, Notifications), then switch this on again.',
              style: GoogleFonts.dmSans(fontSize: 12.5, height: 1.35, color: cs.onErrorContainer),
            ),
          ),
        ],
        if (_on) ...[
          const SizedBox(height: 18),
          heading('Class reminder'),
          const SizedBox(height: 2),
          note('How long before a class starts.'),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(end: index.toDouble()),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (_, pos, _) => NexusSegmented(
              labels: [for (final m in choices) '$m min'],
              position: pos,
              onSelect: (i) async {
                setState(() => _minutes = choices[i]);
                await ReminderService.setClassMinutes(choices[i]);
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading('Exam reminders'),
                    const SizedBox(height: 2),
                    note('At 8 pm the evening before and 7:30 am on the day, with time, venue and seat.'),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _exams,
                onChanged: (v) async {
                  setState(() => _exams = v);
                  await ReminderService.setExams(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          NexusButton(
            label: 'Send a test reminder',
            icon: Icons.notifications_active_outlined,
            onTap: () async {
              final ok = await ReminderService.sendTest();
              if (!context.mounted) return;
              nexusToast(context, ok ? 'Test sent. Check your notifications.' : 'Notifications are blocked for this app.');
            },
          ),
          const SizedBox(height: 14),
          note('Reminders use the timetable and exams from your last sync, so open the app now and then. '
              'If your phone limits background activity for the app, a reminder can arrive a little late.'),
        ],
      ],
    );
  }
}
