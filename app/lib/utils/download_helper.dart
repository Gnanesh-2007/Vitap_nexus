import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class DownloadHelper {
  /// Saves content (text, HTML, or raw bytes) to device storage
  static Future<String?> saveFile({
    required BuildContext context,
    required String fileName,
    required dynamic content, // String or List<int>
    String? mimeType,
  }) async {
    try {
      Directory? dir;

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          // Priority 1: Direct public Download directory on Android
          final publicDownload = Directory('/storage/emulated/0/Download');
          if (await publicDownload.exists()) {
            dir = publicDownload;
          } else {
            dir = await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory();
          }
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          dir = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      }

      dir ??= await getApplicationDocumentsDirectory();

      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${dir.path}/$sanitizedName';
      final file = File(filePath);

      if (content is String) {
        await file.writeAsString(content);
      } else if (content is List<int>) {
        await file.writeAsBytes(content);
      } else {
        throw Exception('Unsupported file content format');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF172B4D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            content: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF278B68).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.download_done_rounded,
                    color: Color(0xFF278B68),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Downloaded to Mobile',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sanitizedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return filePath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC84C43),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Could not download file: $e',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
      return null;
    }
  }

  /// Generates clean HTML template for Outing Gate Pass slip
  static String generateOutingPassHtml({
    required String studentName,
    required String regNo,
    required String outingType,
    required String placeOfVisit,
    required String purpose,
    required String outDateTime,
    required String inDateTime,
    required String contactNumber,
    required String status,
    required String leaveId,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>VIT-AP Outing Gate Pass - $leaveId</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 24px; color: #17202A; background: #FFF; }
    .card { border: 2px solid #172B4D; border-radius: 12px; padding: 24px; max-width: 600px; margin: 0 auto; }
    .header { text-align: center; border-bottom: 2px solid #E2DED5; padding-bottom: 16px; margin-bottom: 20px; }
    .title { font-size: 20px; font-weight: 800; color: #172B4D; margin: 0; }
    .subtitle { font-size: 12px; color: #E47543; font-weight: 700; margin-top: 4px; letter-spacing: 1px; }
    .badge { display: inline-block; padding: 6px 14px; border-radius: 20px; font-weight: 800; font-size: 11px; margin-top: 10px; }
    .badge-approved { background: #E8F5E9; color: #2E7D32; border: 1px solid #A5D6A7; }
    .row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #F0EEE8; font-size: 13px; }
    .label { color: #6E7681; font-weight: 600; }
    .val { font-weight: 700; color: #17202A; text-align: right; }
    .footer { margin-top: 24px; text-align: center; font-size: 10px; color: #8A929A; border-top: 1px dashed #E2DED5; padding-top: 12px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h2 class="title">VIT-AP UNIVERSITY</h2>
      <div class="subtitle">HOSTEL OUTING GATE PASS</div>
      <div class="badge badge-approved">${status.toUpperCase()}</div>
    </div>
    <div class="row"><span class="label">Pass / Application ID:</span><span class="val">$leaveId</span></div>
    <div class="row"><span class="label">Student Name:</span><span class="val">$studentName</span></div>
    <div class="row"><span class="label">Registration No:</span><span class="val">$regNo</span></div>
    <div class="row"><span class="label">Outing Type:</span><span class="val">$outingType</span></div>
    <div class="row"><span class="label">Place of Visit:</span><span class="val">$placeOfVisit</span></div>
    <div class="row"><span class="label">Purpose:</span><span class="val">$purpose</span></div>
    <div class="row"><span class="label">Out Date & Time:</span><span class="val">$outDateTime</span></div>
    <div class="row"><span class="label">Expected Return:</span><span class="val">$inDateTime</span></div>
    <div class="row"><span class="label">Contact / Emergency No:</span><span class="val">$contactNumber</span></div>
    <div class="footer">
      Generated via VIT-AP VTOP Nexus • Valid at Security Gate with Student ID Card
    </div>
  </div>
</body>
</html>
''';
  }

  /// Generates clean HTML template for Exam Schedule
  static String generateExamScheduleHtml({
    required String studentName,
    required String regNo,
    required List<dynamic> exams,
  }) {
    final rows = exams.map((e) {
      final code = e['course_code'] ?? e['code'] ?? '';
      final title = e['course_name'] ?? e['course_title'] ?? e['title'] ?? '';
      final date = e['exam_date'] ?? e['date'] ?? '';
      final session = e['exam_session'] ?? e['session'] ?? e['time'] ?? '';
      final venue = e['venue'] ?? e['room_no'] ?? 'TBA';
      final slot = e['slot'] ?? '';

      return '<tr><td style="padding:10px;border-bottom:1px solid #EEE;"><b>$code</b><br><small style="color:#666;">$title</small></td><td style="padding:10px;border-bottom:1px solid #EEE;">$date</td><td style="padding:10px;border-bottom:1px solid #EEE;">$session ($slot)</td><td style="padding:10px;border-bottom:1px solid #EEE;"><b>$venue</b></td></tr>';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Exam Schedule - $regNo</title>
  <style>
    body { font-family: sans-serif; margin: 24px; color: #17202A; }
    .card { border: 1px solid #E2DED5; border-radius: 12px; padding: 20px; max-width: 800px; margin: 0 auto; }
    h2 { color: #172B4D; margin: 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    th { background: #F4F2ED; padding: 10px; text-align: left; font-size: 12px; color: #172B4D; border-bottom: 2px solid #E2DED5; }
  </style>
</head>
<body>
  <div class="card">
    <h2>VIT-AP UNIVERSITY • EXAM SCHEDULE</h2>
    <p style="color:#6E7681;margin-top:4px;">Student: <b>$studentName</b> ($regNo)</p>
    <table>
      <thead>
        <tr><th>Course</th><th>Exam Date</th><th>Timing & Slot</th><th>Venue</th></tr>
      </thead>
      <tbody>
        $rows
      </tbody>
    </table>
  </div>
</body>
</html>
''';
  }
}
