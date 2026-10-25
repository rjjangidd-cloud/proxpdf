import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class FileSaver {
  // Single file download (PDF/ZIP/etc.)
  static Future<void> downloadFile(
    Uint8List bytes,
    String fileName, {
    BuildContext? context,
    String mimeType = 'application/pdf',
  }) async {
    if (kIsWeb) {
      // --- WEB BROWSER LOGIC (Same as before) ---
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = fileName;

      html.document.body?.children.add(anchor);
      anchor.click();

      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      // --- ANDROID / MOBILE STORAGE LOGIC ---
      try {
        Directory? targetDir;

        if (Platform.isAndroid) {
          // Public Downloads folder path
          final publicDownloadDir = Directory('/storage/emulated/0/Download');
          if (await publicDownloadDir.exists()) {
            targetDir = publicDownloadDir;
          } else {
            targetDir = await getExternalStorageDirectory();
          }
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }

        targetDir ??= await getApplicationDocumentsDirectory();

        final String filePath = '${targetDir.path}/$fileName';
        final File file = File(filePath);

        // Seedhe storage folder me file write karein
        await file.writeAsBytes(bytes);

        // SnackBar ke saath OPEN action button (Pehle jaisa)
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded to storage: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () {
                  OpenFilex.open(filePath);
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Save error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Multiple files ko ZIP bana kar download karne ke liye (Same as before)
  static Future<void> downloadZip(
    List<Uint8List> files,
    String zipFileName, {
    BuildContext? context,
    String filePrefix = 'page',
  }) async {
    final archive = Archive();

    for (int i = 0; i < files.length; i++) {
      final fileName = '${filePrefix}_${i + 1}.pdf';
      final fileData = files[i];
      archive.addFile(ArchiveFile(fileName, fileData.length, fileData));
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      await downloadFile(
        Uint8List.fromList(zipData),
        zipFileName,
        context: context,
        mimeType: 'application/zip',
      );
    }
  }
}