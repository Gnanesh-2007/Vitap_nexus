import 'dart:convert';
import 'dart:io';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitap_nexus_app/utils/error_formatter.dart';

class DownloadHelper {
  /// Primary color constants for consistent theme
  static const Color _navy = Color(0xFF172B4D);
  static const Color _green = Color(0xFF278B68);

  /// Saves official file content (bytes, PDF, or text) from VTOP directly to public
  /// device storage (Downloads folder) using native Android MediaStore / FileSaver,
  /// making it visible in the phone's "Files" and "Downloads" app immediately.
  static Future<String?> saveFile({
    required BuildContext context,
    required String fileName,
    required dynamic content, // String, Uint8List, List<int>, or List<dynamic>
    String? mimeType,
    bool openImmediately = false,
    bool promptSaveAs = true,
  }) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      Uint8List bytes;
      if (content is Uint8List) {
        bytes = content;
      } else if (content is List<int>) {
        bytes = Uint8List.fromList(content);
      } else if (content is List) {
        bytes = Uint8List.fromList(content.map((e) => (e as num).toInt()).toList());
      } else if (content is String) {
        bytes = Uint8List.fromList(utf8.encode(content));
      } else {
        throw Exception('Unsupported file content format');
      }

      // 1. Extract base name and extension
      String baseName = sanitizedName;
      String ext = 'pdf';
      final dotIndex = sanitizedName.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < sanitizedName.length - 1) {
        baseName = sanitizedName.substring(0, dotIndex);
        ext = sanitizedName.substring(dotIndex + 1).toLowerCase();
      }

      final resolvedMimeType = _resolveMimeType(ext);

      // Web platform fast path: directly trigger browser download
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: baseName,
          bytes: bytes,
          fileExtension: ext,
          mimeType: resolvedMimeType,
          customMimeType: mimeType,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _navy,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF48CF9B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Downloaded $sanitizedName successfully.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return sanitizedName;
      }

      // Mobile / Desktop native storage path — Target Public Downloads directly
      Directory? dir;
      if (Platform.isAndroid) {
        final publicDownloads = Directory('/storage/emulated/0/Download');
        if (publicDownloads.existsSync()) {
          dir = publicDownloads;
        } else {
          try {
            dir = await getDownloadsDirectory();
          } catch (_) {}
        }
      } else if (!Platform.isIOS) {
        try {
          dir = await getDownloadsDirectory();
        } catch (_) {}
      }
      dir ??= await getApplicationDocumentsDirectory();
      final localFilePath = '${dir.path}/$sanitizedName';
      final file = File(localFilePath);
      try {
        await file.writeAsBytes(bytes, flush: true);
      } catch (_) {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${fallbackDir.path}/$sanitizedName');
        await fallbackFile.writeAsBytes(bytes, flush: true);
      }

      // Save to device storage / Prompt native Save As file picker
      if (promptSaveAs) {
        try {
          await FileSaver.instance.saveAs(
            name: baseName,
            bytes: bytes,
            fileExtension: ext,
            mimeType: resolvedMimeType,
            customMimeType: mimeType,
          );
        } catch (fsErr) {
          debugPrint('FileSaver.saveAs error / cancelled: $fsErr');
        }
      } else {
        try {
          await FileSaver.instance.saveFile(
            name: baseName,
            bytes: bytes,
            fileExtension: ext,
            mimeType: resolvedMimeType,
            customMimeType: mimeType,
          );
        } catch (fsErr) {
          debugPrint('FileSaver.saveFile error: $fsErr');
        }
      }

      if (openImmediately) {
        await openFile(localFilePath);
      }

      if (context.mounted) {
        showDownloadModal(
          context: context,
          filePath: localFilePath,
          fileName: sanitizedName,
          fileBytes: bytes,
          baseName: baseName,
          ext: ext,
          mimeType: resolvedMimeType,
          customMimeType: mimeType,
        );
      }
      return localFilePath;
    } catch (e) {
      if (context.mounted) {
        final friendlyMsg = ErrorFormatter.format(e, fallback: 'Unable to save the file. Please check storage permissions or try again.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC84C43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              friendlyMsg,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        );
      }
      return null;
    }
  }

  static MimeType _resolveMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return MimeType.pdf;
      case 'png':
        return MimeType.png;
      case 'jpg':
      case 'jpeg':
        return MimeType.jpeg;
      case 'doc':
      case 'docx':
        return MimeType.microsoftWord;
      case 'xls':
      case 'xlsx':
        return MimeType.microsoftExcel;
      case 'ppt':
      case 'pptx':
        return MimeType.microsoftPresentation;
      case 'zip':
      case 'rar':
      case '7z':
        return MimeType.zip;
      case 'txt':
        return MimeType.text;
      default:
        return MimeType.other;
    }
  }

  /// Opens the file using the native device application (Chrome/PDF/Viewer)
  static Future<OpenResult?> openFile(String filePath) async {
    if (kIsWeb) return null;
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

  /// Generates the exact official VIT-AP Hostel Out Pass PDF document
  static Future<Uint8List> generateOfficialOutingPdfBytes({
    required String studentName,
    required String regNo,
    required String outingType, // 'Weekend' or 'General'
    required String placeOfVisit,
    required String purpose,
    required String dateTimeSlot,
    required String contactNumber,
    required String parentContactNumber,
    required String bookingId,
    String? applicationDate,
    String? hostelBlock,
    String? roomNo,
  }) async {
    final pdf = pw.Document();
    final isWeekend = outingType.toLowerCase().contains('weekend');
    final title = isWeekend ? 'HOSTEL WEEKEND OUT PASS' : 'HOSTEL GENERAL OUT PASS';
    final dateStr = applicationDate ?? DateFormat('dd-MM-yyyy').format(DateTime.now());

    final qrData = 'VIT-AP UNIVERSITY\nOUT PASS ID: $bookingId\nREG NO: $regNo\nNAME: $studentName\nROOM: ${hostelBlock ?? ""} - ${roomNo ?? ""}\nDATE: $dateTimeSlot\nVERIFIED VTOP DIGITAL PASS';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 36),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header Title
              pw.Text(
                'VIT-AP UNIVERSITY',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF7A1B28),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Vellore Institute of Technology – Andhra Pradesh',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '(State Private University Under The AP State Private Universities (Establishment and Regulation) Act, 2016)',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Amaravati, Andhra Pradesh – 522 237, India, Web : www.vitap.ac.in',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 22),

              // Title Underlined
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 11.5,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 18),

              // Outing ID & Date on left, QR on right
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Outing ID : $bookingId',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Date: $dateStr',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 75,
                    height: 75,
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // Numbered Info Spec
              pw.Column(
                children: [
                  _pdfRow('1. Regd No', regNo),
                  _pdfRow('2. Name', studentName.toUpperCase()),
                  _pdfRow('3. Hostel Block', hostelBlock ?? 'MH-5'),
                  _pdfRow('4. Hostel Room No', roomNo ?? '1102'),
                  _pdfRow('5. Place Of Visit', placeOfVisit),
                  _pdfRow('6. Purpose Of Visit', purpose),
                  _pdfRow('7. Date & Time Slot', dateTimeSlot),
                  _pdfRow('8. Contact No', contactNumber),
                  _pdfRow('9. Parent Contact Number', parentContactNumber),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Text(
                'VIT-AP - Apply Knowledge. Improve Life!™',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'This is a system-generated document. No signature is required',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '1/1',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 170,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(
            width: 25,
            child: pw.Text(
              ':',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generates official VIT-AP University Payment Receipt PDF document
  static Future<Uint8List> generateOfficialPaymentReceiptPdfBytes({
    required String studentName,
    required String regNo,
    required String receiptNo,
    required String amount,
    required String date,
    String? applicationNumber,
    String? invoiceNo,
    String? feeGroup,
    String? feeSubgroup,
    String? campusCode,
    String? paymentMode,
    String? paymentStatus,
    String? programName,
  }) async {
    final pdf = pw.Document();
    final qrData = 'VIT-AP UNIVERSITY\nOFFICIAL PAYMENT RECEIPT\nRECEIPT NO: $receiptNo\nREG NO: $regNo\nNAME: $studentName\nAMOUNT: INR $amount\nDATE: $date\nSTATUS: ${paymentStatus ?? "PAID"}';

    // Format amount cleanly
    String formattedAmount = amount;
    try {
      final numVal = double.tryParse(amount.replaceAll(',', ''));
      if (numVal != null) {
        formattedAmount = 'INR ${NumberFormat('#,##,##0.00', 'en_IN').format(numVal)}';
      }
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 36),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header Title
              pw.Text(
                'VIT-AP UNIVERSITY',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF7A1B28),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Vellore Institute of Technology – Andhra Pradesh',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '(State Private University Under The AP State Private Universities Act, 2016)',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Beside AP Secretariat, Near Vijayawada, Amaravati – 522 237, Andhra Pradesh, India',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 18),

              // Sub-header banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF0EEE8),
                  border: pw.Border.symmetric(
                    horizontal: pw.BorderSide(color: PdfColor.fromInt(0xFF172B4D), width: 1),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'STUDENT FEE PAYMENT RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                      color: PdfColor.fromInt(0xFF172B4D),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 18),

              // Receipt Meta Row + QR
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Receipt No: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(receiptNo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF7A1B28))),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      if (invoiceNo != null && invoiceNo.isNotEmpty) ...[
                        pw.Row(
                          children: [
                            pw.Text('Invoice No: ', style: const pw.TextStyle(fontSize: 9.5)),
                            pw.Text(invoiceNo, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                      ],
                      pw.Row(
                        children: [
                          pw.Text('Receipt Date: ', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.Text(date, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Campus Code: ', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.Text(campusCode ?? 'AMR', style: const pw.TextStyle(fontSize: 9.5)),
                        ],
                      ),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 70,
                    height: 70,
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // Student Details Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('STUDENT INFORMATION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF7A1B28))),
                    pw.SizedBox(height: 6),
                    _pdfReceiptRow('Registration Number', regNo),
                    _pdfReceiptRow('Student Name', studentName.toUpperCase()),
                    if (applicationNumber != null && applicationNumber.isNotEmpty)
                      _pdfReceiptRow('Application Number', applicationNumber),
                    if (programName != null && programName.isNotEmpty)
                      _pdfReceiptRow('Program / Branch', programName),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Fee Breakdown Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F2ED)),
                    children: [
                      _tableCell('S.No', isHeader: true, align: pw.TextAlign.center),
                      _tableCell('Fee Description', isHeader: true),
                      _tableCell('Category / Group', isHeader: true),
                      _tableCell('Amount (INR)', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell('1', align: pw.TextAlign.center),
                      _tableCell(feeSubgroup ?? feeGroup ?? 'University Academic / Hostel Fees'),
                      _tableCell(feeGroup ?? 'FEES'),
                      _tableCell(formattedAmount.replaceFirst('INR ', ''), align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFAFA)),
                    children: [
                      _tableCell(''),
                      _tableCell('TOTAL AMOUNT PAID', isHeader: true),
                      _tableCell(''),
                      _tableCell(formattedAmount.replaceFirst('INR ', ''), isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // Transaction Summary
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF9FAF8),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payment Mode : ${paymentMode ?? "Online Banking / Gateway"}', style: const pw.TextStyle(fontSize: 9.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Payment Status: ${paymentStatus ?? "PAID / SUCCESSFUL"}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF278B68))),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Paid', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(formattedAmount, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF172B4D))),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signature and Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Note: Receipt generated electronically via VIT-AP VTOP.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text('Please retain this document for hostel and academic verification.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColor.fromInt(0xFF278B68), width: 1),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'OFFICIALLY VERIFIED',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF278B68),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Finance Officer / Accounts Office', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VIT-AP University • Apply Knowledge. Improve Life!™', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(
            width: 20,
            child: pw.Text(
              ':',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 9.5 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  /// Converts official VTOP receipt HTML markup into authentic PDF bytes
  static Future<Uint8List?> convertOfficialReceiptHtmlToPdf(String receiptHtml) async {
    try {
      var html = receiptHtml.trim();
      if (!html.contains('<html') && !html.contains('<body')) {
        html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; color: #17202A; background: #FFF; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; margin-bottom: 12px; }
    th, td { border: 1px solid #C3BCB0; padding: 7px 10px; font-size: 11px; }
    th { background-color: #F4F2ED; font-weight: bold; }
    .header { text-align: center; margin-bottom: 16px; }
    .title { font-size: 18px; font-weight: bold; color: #7A1B28; margin: 0; }
    .subtitle { font-size: 12px; font-weight: bold; color: #172B4D; margin-top: 2px; }
  </style>
</head>
<body>
  $html
</body>
</html>
''';
      }

      // ignore: deprecated_member_use
      return await Printing.convertHtml(
        html: html,
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      debugPrint('convertOfficialReceiptHtmlToPdf error: $e');
      return null;
    }
  }

  /// Generates clean Official Outing Gate Pass Slip HTML document
  static String generateOutingPassSlip({
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
    String? hostelBlock,
    String? roomNo,
  }) {
    final isApproved = status.toLowerCase().contains('app');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VIT-AP Hostel Outing Gate Pass - $leaveId</title>
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
      <div class="badge ${isApproved ? 'badge-approved' : 'badge-pending'}">${status.toUpperCase()}</div>
    </div>
    <div class="row"><span class="label">Pass / Application ID</span><span class="val">$leaveId</span></div>
    <div class="row"><span class="label">Student Name</span><span class="val">$studentName</span></div>
    <div class="row"><span class="label">Registration No</span><span class="val">$regNo</span></div>
    ${hostelBlock != null && hostelBlock.isNotEmpty ? '<div class="row"><span class="label">Hostel & Room</span><span class="val">$hostelBlock ${roomNo != null && roomNo.isNotEmpty ? '• Rm $roomNo' : ''}</span></div>' : ''}
    <div class="row"><span class="label">Outing Type</span><span class="val">$outingType</span></div>
    <div class="row"><span class="label">Place of Visit</span><span class="val">$placeOfVisit</span></div>
    <div class="row"><span class="label">Purpose of Outing</span><span class="val">$purpose</span></div>
    <div class="row"><span class="label">Out Date & Time</span><span class="val">$outDateTime</span></div>
    <div class="row"><span class="label">Expected Return</span><span class="val">$inDateTime</span></div>
    <div class="row"><span class="label">Contact / Emergency</span><span class="val">$contactNumber</span></div>
    <div class="qr-box">
      SECURITY VERIFICATION TOKEN: [ $leaveId - $regNo ]
    </div>
    <div class="footer">
      Generated via VIT-AP VTOP Nexus • Valid at Hostel Main Security Gate with Student Physical ID Card
    </div>
  </div>
</body>
</html>
''';
  }

  /// Shows a comprehensive, interactive bottom sheet modal with immediate Open,
  /// Save to Device Storage, and Share actions.
  static void showDownloadModal({
    required BuildContext context,
    required String filePath,
    required String fileName,
    required Uint8List fileBytes,
    required String baseName,
    required String ext,
    required MimeType mimeType,
    String? customMimeType,
  }) {
    // Format file size nicely
    final sizeKb = fileBytes.lengthInBytes / 1024;
    final sizeStr = sizeKb > 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '${sizeKb.toStringAsFixed(0)} KB';

    // Pick icon and color for extension
    IconData fileIcon = Icons.insert_drive_file_rounded;
    Color iconColor = const Color(0xFF172B4D);
    Color iconBg = const Color(0xFFE9EEF5);

    if (ext == 'pdf') {
      fileIcon = Icons.picture_as_pdf_rounded;
      iconColor = const Color(0xFFC84C43);
      iconBg = const Color(0xFFFDE8E6);
    } else if (ext == 'zip' || ext == 'rar' || ext == '7z') {
      fileIcon = Icons.folder_zip_rounded;
      iconColor = const Color(0xFFE47543);
      iconBg = const Color(0xFFFDEEE6);
    } else if (ext == 'doc' || ext == 'docx') {
      fileIcon = Icons.description_rounded;
      iconColor = const Color(0xFF2E66E7);
      iconBg = const Color(0xFFE8EFFF);
    } else if (ext == 'xls' || ext == 'xlsx') {
      fileIcon = Icons.table_chart_rounded;
      iconColor = const Color(0xFF278B68);
      iconBg = const Color(0xFFE6F5EE);
    } else if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
      fileIcon = Icons.image_rounded;
      iconColor = const Color(0xFF7A1B28);
      iconBg = const Color(0xFFF8E7E9);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A2332) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF17202A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF6E7681);
    final cardBorder = isDark ? const Color(0xFF2C3B50) : const Color(0xFFE2DED5);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // File Header Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222E42) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(fileIcon, color: iconColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ext.toUpperCase(),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sizeStr,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    color: subColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.check_circle_rounded, size: 13, color: _green),
                                const SizedBox(width: 3),
                                Text(
                                  'Downloaded',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: _green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Primary Action: Open File
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(modalCtx).pop();
                      openFile(filePath);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      'Open File',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Row: Save As... + Share
                Row(
                  children: [
                    // Save to folder / Save As
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(modalCtx).pop();
                            try {
                              await FileSaver.instance.saveAs(
                                name: baseName,
                                bytes: fileBytes,
                                fileExtension: ext,
                                mimeType: mimeType,
                                customMimeType: customMimeType,
                              );
                            } catch (e) {
                              debugPrint('SaveAs error: $e');
                            }
                          },
                          icon: const Icon(Icons.drive_file_move_outline, size: 17),
                          label: Text(
                            'Save to Device',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Share
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(modalCtx).pop();
                            shareFile(filePath, title: fileName);
                          },
                          icon: const Icon(Icons.share_rounded, size: 17),
                          label: Text(
                            'Share / Export',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

