import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/academic_report.dart';
import 'journey_widgets.dart' show shortSemester;

/// Builds a printable, A4 version of the Academic Journey.
///
/// It is always labelled as computed on the phone and not an official
/// transcript. When the grades have been edited or courses added, a prominent
/// banner says so, and every changed grade is marked with an asterisk, so a
/// simulation can never be mistaken for the VTOP record.
Future<Uint8List> buildJourneyPdf(
  AcademicReport r, {
  required bool whatIf,
  Set<String> changed = const {},
  required DateTime now,
}) async {
  final doc = pw.Document(title: 'VITAP Nexus - Academic report', author: 'VITAP Nexus');

  const ink = PdfColor.fromInt(0xFF17202A);
  const soft = PdfColor.fromInt(0xFF5B6674);
  const line = PdfColor.fromInt(0xFFD9DEE6);
  const tint = PdfColor.fromInt(0xFFF1F4F9);
  const amber = PdfColor.fromInt(0xFFB45309);
  const amberBg = PdfColor.fromInt(0xFFFEF3C7);

  String t(String s) => _ascii(s);
  String num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final date = '${now.day} ${months[now.month - 1]} ${now.year}';

  pw.Widget stat(String label, String value) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: tint, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 7.5, color: soft, letterSpacing: 1)),
              pw.SizedBox(height: 4),
              pw.Text(value, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: ink)),
            ],
          ),
        ),
      );

  final mix = [
    for (final g in kGradeOrder)
      if ((r.gradeCounts[g] ?? 0) > 0) '${g == 'P' ? 'Pass' : g} ${r.gradeCounts[g]}',
  ].join('    ');

  final blocks = <pw.Widget>[
    pw.Text('Academic report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: ink)),
    pw.SizedBox(height: 3),
    pw.Text('Generated $date with VITAP Nexus', style: const pw.TextStyle(fontSize: 10, color: soft)),
    pw.SizedBox(height: 14),
    if (whatIf) ...[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: amberBg, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Text(
          'WHAT-IF SIMULATION. This report includes changed or planned grades${changed.isEmpty ? '' : ' (marked with *)'}. '
          'It is not your VTOP record.',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: amber),
        ),
      ),
      pw.SizedBox(height: 12),
    ],
    pw.Row(
      children: [
        stat('CGPA', r.cgpa == null ? '--' : r.cgpa!.toStringAsFixed(2)),
        stat('Courses', '${r.courseCount}'),
        stat('Credits', '${num(r.creditsEarned)} of ${num(r.creditsRegistered)}'),
        stat('Semesters', '${r.semesters.length}'),
      ],
    ),
    pw.SizedBox(height: 10),
    if (mix.isNotEmpty)
      pw.Text(
        'Grades: $mix    -    ${(r.topShare * 100).round()}% of graded credits at A or better',
        style: const pw.TextStyle(fontSize: 9.5, color: soft),
      ),
    pw.SizedBox(height: 16),
  ];

  for (final s in r.semesters) {
    final delta = s.delta;
    blocks.add(
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 5),
        margin: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(t(s.label), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
            pw.SizedBox(width: 10),
            pw.Text(
              'SGPA ${s.gpa == null ? '--' : s.gpa!.toStringAsFixed(2)}'
              '${delta == null ? '' : '  (${delta >= 0 ? '+' : '-'}${delta.abs().toStringAsFixed(2)})'}'
              '   ${num(s.credits)} credits   ${s.courses.length} courses',
              style: const pw.TextStyle(fontSize: 9.5, color: soft),
            ),
          ],
        ),
      ),
    );
    blocks.add(
      pw.TableHelper.fromTextArray(
        headers: const ['Code', 'Course', 'Type', 'Credits', 'Grade', 'Points'],
        data: [
          for (final c in s.courses)
            [
              c.code.startsWith('PLAN-') ? 'Planned' : c.code,
              t(c.title),
              c.type,
              num(c.credits),
              '${c.grade}${changed.contains(courseKey(c.code, c.semester)) || c.code.startsWith('PLAN-') ? '*' : ''}',
              c.points?.toString() ?? '-',
            ],
        ],
        headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: ink),
        headerDecoration: const pw.BoxDecoration(color: tint),
        cellStyle: const pw.TextStyle(fontSize: 9, color: ink),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
          4: pw.Alignment.center,
          5: pw.Alignment.center,
        },
        columnWidths: {
          0: const pw.FixedColumnWidth(62),
          1: const pw.FlexColumnWidth(),
          2: const pw.FixedColumnWidth(40),
          3: const pw.FixedColumnWidth(46),
          4: const pw.FixedColumnWidth(42),
          5: const pw.FixedColumnWidth(42),
        },
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.5), bottom: pw.BorderSide(color: line, width: 0.5)),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      ),
    );
    blocks.add(pw.SizedBox(height: 12));
  }

  // A line chart of the path, drawn from the same numbers.
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 38, 36, 38),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Computed on this phone from your VTOP grade history. Not an official transcript.   Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: soft),
        ),
      ),
      build: (ctx) => [
        ...blocks,
        if (r.semesters.length >= 2) ...[
          pw.SizedBox(height: 6),
          pw.Text('Path', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final s in r.semesters)
                pw.Text(
                  '${shortSemester(s.label)}: SGPA ${s.gpa?.toStringAsFixed(2) ?? '--'}, CGPA ${s.cumulative?.toStringAsFixed(2) ?? '--'}',
                  style: const pw.TextStyle(fontSize: 9, color: soft),
                ),
            ],
          ),
        ],
      ],
    ),
  );

  return doc.save();
}

/// The built-in PDF fonts only cover Latin-1; anything else becomes a dash so
/// a stray symbol in a course title can never break the export.
String _ascii(String s) => String.fromCharCodes([
      for (final c in s.runes) c <= 255 ? c : 0x2D,
    ]);
