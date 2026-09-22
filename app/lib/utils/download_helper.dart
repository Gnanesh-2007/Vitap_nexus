import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DownloadHelper {
  /// Primary color constants for consistent theme
  static const Color _navy = Color(0xFF172B4D);
  static const Color _green = Color(0xFF278B68);
  static const Color _orange = Color(0xFFE47543);

  /// Saves official file content (bytes, PDF, or text) from VTOP to device storage
  /// and presents interactive Open and Share options immediately to the user.
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

  /// Opens the file using the native device application (Chrome/PDF/Viewer)
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
}
