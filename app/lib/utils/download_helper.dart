import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DownloadHelper {
  /// Primary color constants for consistent theme
  static const Color _ink = Color(0xFF17202A);
  static const Color _navy = Color(0xFF172B4D);
  static const Color _green = Color(0xFF278B68);
  static const Color _orange = Color(0xFFE47543);
  static const Color _paper = Color(0xFFFBF9F4);
  static const Color _line = Color(0xFFE2DED5);

  /// Saves content (text, HTML, or raw bytes) to device storage and presents
  /// interactive Open and Share options immediately to the user.
  static Future<String?> saveFile({
    required BuildContext context,
    required String fileName,
    required dynamic content, // String or List<int>
    String? mimeType,
    bool openImmediately = false,
  }) async {
    try {
      Directory? dir;

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          // Attempt direct Android Download directory first
          try {
            final publicDownload = Directory('/storage/emulated/0/Download');
            if (await publicDownload.exists()) {
              dir = publicDownload;
            }
          } catch (_) {}

          dir ??= await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
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

      if (openImmediately) {
        await openFile(filePath);
      }

      if (context.mounted) {
        _showDownloadSuccessBanner(
          context: context,
          filePath: filePath,
          fileName: sanitizedName,
        );
      }
      return filePath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC84C43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// Opens the file using the native device application (Chrome/Viewer/PDF)
  static Future<OpenResult> openFile(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  /// Opens system share dialog to save to Drive, Files, WhatsApp, etc.
  static Future<void> shareFile(String filePath, {String? title}) async {
    final xFile = XFile(filePath);
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [xFile],
      text: title ?? 'Shared from VIT-AP VTOP Nexus',
    );
  }

  /// Shows an interactive bottom sheet or SnackBar with immediate Open and Share actions
  static void _showDownloadSuccessBanner({
    required BuildContext context,
    required String filePath,
    required String fileName,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        backgroundColor: _navy,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E3F5F), width: 1),
        ),
        content: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _green.withValues(alpha: 0.4)),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF48CF9B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved to Mobile',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName,
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
            const SizedBox(width: 8),
            // Open Button
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                openFile(filePath);
              },
              style: TextButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'OPEN',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Share Button
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                shareFile(filePath, title: fileName);
              },
              tooltip: 'Share File',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              icon: const Icon(
                Icons.share_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays an in-app viewer modal for HTML passes, slips, or reports with
  /// instant Save, Open External, and Share capabilities
  static void showPreviewModal({
    required BuildContext context,
    required String title,
    required String fileName,
    required String htmlContent,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.dmSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                fileName,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  color: const Color(0xFF6E7681),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: _ink),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _line),
                  // Content preview / details
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _line),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _stripHtml(htmlContent),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            height: 1.6,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Actions Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: _line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final path = await saveFile(
                                context: context,
                                fileName: fileName,
                                content: htmlContent,
                                mimeType: 'text/html',
                              );
                              if (path != null) {
                                await shareFile(path, title: fileName);
                              }
                            },
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: Text(
                              'Share Pass',
                              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _navy,
                              side: const BorderSide(color: _line),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await saveFile(
                                context: context,
                                fileName: fileName,
                                content: htmlContent,
                                mimeType: 'text/html',
                                openImmediately: true,
                              );
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: Text(
                              'Open in Mobile',
                              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '\n')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
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
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VIT-AP Outing Gate Pass - $leaveId</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 16px; color: #17202A; background: #F8F9FA; }
    .card { background: #FFF; border: 2px solid #172B4D; border-radius: 16px; padding: 24px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
    .header { text-align: center; border-bottom: 2px solid #E2DED5; padding-bottom: 16px; margin-bottom: 20px; }
    .title { font-size: 20px; font-weight: 800; color: #172B4D; margin: 0; letter-spacing: 0.5px; }
    .subtitle { font-size: 13px; color: #E47543; font-weight: 700; margin-top: 4px; letter-spacing: 1px; }
    .badge { display: inline-block; padding: 6px 16px; border-radius: 20px; font-weight: 800; font-size: 12px; margin-top: 12px; letter-spacing: 0.5px; }
    .badge-approved { background: #E8F5E9; color: #2E7D32; border: 1.5px solid #A5D6A7; }
    .badge-pending { background: #FFF8E1; color: #F57F17; border: 1.5px solid #FFE082; }
    .row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #F0EEE8; font-size: 13.5px; }
    .label { color: #6E7681; font-weight: 600; }
    .val { font-weight: 700; color: #17202A; text-align: right; }
    .qr-box { text-align: center; margin: 20px 0 10px 0; padding: 14px; background: #F4F2ED; border-radius: 10px; font-family: monospace; font-weight: bold; color: #172B4D; font-size: 13px; border: 1px dashed #C3BCB0; }
    .footer { margin-top: 20px; text-align: center; font-size: 11px; color: #8A929A; border-top: 1px dashed #E2DED5; padding-top: 14px; line-height: 1.4; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="title">VIT-AP UNIVERSITY</div>
      <div class="subtitle">HOSTEL OUTING GATE PASS</div>
      <div class="badge ${status.toLowerCase().contains('app') ? 'badge-approved' : 'badge-pending'}">${status.toUpperCase()}</div>
    </div>
    <div class="row"><span class="label">Pass / Application ID</span><span class="val">$leaveId</span></div>
    <div class="row"><span class="label">Student Name</span><span class="val">$studentName</span></div>
    <div class="row"><span class="label">Registration No</span><span class="val">$regNo</span></div>
    <div class="row"><span class="label">Outing Type</span><span class="val">$outingType</span></div>
    <div class="row"><span class="label">Place of Visit</span><span class="val">$placeOfVisit</span></div>
    <div class="row"><span class="label">Purpose</span><span class="val">$purpose</span></div>
    <div class="row"><span class="label">Out Date & Time</span><span class="val">$outDateTime</span></div>
    <div class="row"><span class="label">Expected Return</span><span class="val">$inDateTime</span></div>
    <div class="row"><span class="label">Contact Number</span><span class="val">$contactNumber</span></div>
    <div class="qr-box">
      SECURITY VERIFICATION TOKEN: [ $leaveId - $regNo ]
    </div>
    <div class="footer">
      Generated via VIT-AP VTOP Nexus • Valid at Hostel Security Gate with Student ID Card
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
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Exam Schedule - $regNo</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 16px; color: #17202A; background: #F8F9FA; }
    .card { background: #FFF; border: 1.5px solid #E2DED5; border-radius: 14px; padding: 20px; max-width: 800px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.06); }
    h2 { color: #172B4D; margin: 0 0 4px 0; font-size: 18px; font-weight: 800; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 13px; }
    th { background: #F4F2ED; padding: 10px; text-align: left; font-size: 12px; color: #172B4D; border-bottom: 2px solid #E2DED5; }
  </style>
</head>
<body>
  <div class="card">
    <h2>VIT-AP UNIVERSITY • EXAM SCHEDULE</h2>
    <p style="color:#6E7681;margin-top:4px;font-size:13px;">Student: <b>$studentName</b> ($regNo)</p>
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

  /// Generates clean HTML template for Marks Report
  static String generateMarksHtml({
    required String studentName,
    required String regNo,
    required List<dynamic> marksList,
  }) {
    final rows = marksList.map((item) {
      final code = item['course_code'] ?? item['code'] ?? '';
      final title = item['course_name'] ?? item['course_title'] ?? item['title'] ?? '';
      final type = item['course_type'] ?? '';
      final total = item['total_marks'] ?? item['total'] ?? item['grand_total'] ?? 'N/A';
      return '<tr><td style="padding:10px;border-bottom:1px solid #EEE;"><b>$code</b><br><small style="color:#666;">$title ($type)</small></td><td style="padding:10px;border-bottom:1px solid #EEE;font-weight:bold;color:#172B4D;">$total</td></tr>';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Marks Report - $regNo</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 16px; color: #17202A; background: #F8F9FA; }
    .card { background: #FFF; border: 1.5px solid #E2DED5; border-radius: 14px; padding: 20px; max-width: 800px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.06); }
    h2 { color: #172B4D; margin: 0 0 4px 0; font-size: 18px; font-weight: 800; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 13px; }
    th { background: #F4F2ED; padding: 10px; text-align: left; font-size: 12px; color: #172B4D; border-bottom: 2px solid #E2DED5; }
  </style>
</head>
<body>
  <div class="card">
    <h2>VIT-AP UNIVERSITY • MARKS REPORT</h2>
    <p style="color:#6E7681;margin-top:4px;font-size:13px;">Student: <b>$studentName</b> ($regNo)</p>
    <table>
      <thead>
        <tr><th>Course & Title</th><th>Total / Score</th></tr>
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

  /// Generates clean HTML template for Payment Receipt
  static String generatePaymentReceiptHtml({
    required String studentName,
    required String regNo,
    required String receiptNo,
    required String amount,
    required String txnDate,
    required String paymentMode,
    required String description,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VIT-AP Fee Receipt - $receiptNo</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 16px; color: #17202A; background: #F8F9FA; }
    .card { background: #FFF; border: 2px solid #172B4D; border-radius: 16px; padding: 24px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
    .header { text-align: center; border-bottom: 2px solid #E2DED5; padding-bottom: 16px; margin-bottom: 20px; }
    .title { font-size: 20px; font-weight: 800; color: #172B4D; margin: 0; }
    .subtitle { font-size: 12px; color: #278B68; font-weight: 700; margin-top: 4px; letter-spacing: 1px; }
    .badge { display: inline-block; padding: 6px 16px; border-radius: 20px; font-weight: 800; font-size: 12px; margin-top: 10px; background: #E8F5E9; color: #2E7D32; border: 1.5px solid #A5D6A7; }
    .row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #F0EEE8; font-size: 13.5px; }
    .label { color: #6E7681; font-weight: 600; }
    .val { font-weight: 700; color: #17202A; text-align: right; }
    .total-box { margin-top: 16px; padding: 14px; background: #F4F2ED; border-radius: 10px; display: flex; justify-content: space-between; font-size: 15px; font-weight: 800; color: #172B4D; }
    .footer { margin-top: 20px; text-align: center; font-size: 11px; color: #8A929A; border-top: 1px dashed #E2DED5; padding-top: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="title">VIT-AP UNIVERSITY</div>
      <div class="subtitle">ONLINE FEE RECEIPT</div>
      <div class="badge">PAYMENT SUCCESSFUL</div>
    </div>
    <div class="row"><span class="label">Receipt Number</span><span class="val">$receiptNo</span></div>
    <div class="row"><span class="label">Student Name</span><span class="val">$studentName</span></div>
    <div class="row"><span class="label">Registration No</span><span class="val">$regNo</span></div>
    <div class="row"><span class="label">Transaction Date</span><span class="val">$txnDate</span></div>
    <div class="row"><span class="label">Payment Mode</span><span class="val">$paymentMode</span></div>
    <div class="row"><span class="label">Description / Head</span><span class="val">$description</span></div>
    <div class="total-box">
      <span>Amount Paid:</span>
      <span>₹$amount</span>
    </div>
    <div class="footer">
      Generated electronically via VIT-AP VTOP Nexus • Valid without physical signature
    </div>
  </div>
</body>
</html>
''';
  }
}
