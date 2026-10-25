import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:excel/excel.dart' as ex;

import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:image/image.dart' as img;

/// User chooses this, or leaves it on [auto] and lets the service decide.
enum PdfCompressionMode { auto, low, medium, high, extreme }

/// Internal: how aggressively we rasterize a page when the PDF turns out
/// to be scanned / image-heavy.
class _RasterProfile {
  final double maxWidth; // page will never be upscaled beyond its own width
  final int jpegQuality;
  const _RasterProfile(this.maxWidth, this.jpegQuality);

  @override
  String toString() => 'width<=$maxWidth,q=$jpegQuality';
}

/// Returned by [PDFService.compressPDFWithStats] so callers can see exactly
/// what happened instead of guessing from file size alone.
class PdfCompressionResult {
  final Uint8List bytes;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final double reductionPercent;
  final String strategyUsed;
  final bool looksScanned;

  const PdfCompressionResult({
    required this.bytes,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.reductionPercent,
    required this.strategyUsed,
    required this.looksScanned,
  });

  @override
  String toString() =>
      'PdfCompressionResult(original: ${(originalSizeBytes / 1024).toStringAsFixed(1)}KB, '
      'compressed: ${(compressedSizeBytes / 1024).toStringAsFixed(1)}KB, '
      'reduction: ${reductionPercent.toStringAsFixed(1)}%, '
      'strategy: $strategyUsed, looksScanned: $looksScanned)';
}

class PDFService {
  // ============ 1. MERGE PDF ============
  static Future<Uint8List> mergePDFs(List<Uint8List> pdfFiles) async {
    try {
      final PdfDocument outputPdf = PdfDocument();

      for (final fileData in pdfFiles) {
        final PdfDocument inputPdf = PdfDocument(inputBytes: fileData);
        for (int i = 0; i < inputPdf.pages.count; i++) {
          final PdfTemplate template = inputPdf.pages[i].createTemplate();
          final PdfPage page = outputPdf.pages.add();
          page.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            page.getClientSize(),
          );
        }
        inputPdf.dispose();
      }

      final List<int> bytes = outputPdf.saveSync();
      outputPdf.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to merge PDFs: $e');
    }
  }

  // ============ 2. SPLIT PDF ============
  static Future<List<Uint8List>> splitPDF(Uint8List pdfFile) async {
    try {
      final PdfDocument inputPdf = PdfDocument(inputBytes: pdfFile);
      final List<Uint8List> splitFiles = [];

      for (int i = 0; i < inputPdf.pages.count; i++) {
        final PdfDocument singlePagePdf = PdfDocument();
        final PdfTemplate template = inputPdf.pages[i].createTemplate();
        final PdfPage page = singlePagePdf.pages.add();
        page.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          page.getClientSize(),
        );

        splitFiles.add(Uint8List.fromList(singlePagePdf.saveSync()));
        singlePagePdf.dispose();
      }

      inputPdf.dispose();
      return splitFiles;
    } catch (e) {
      throw Exception('Failed to split PDF: $e');
    }
  }

  static Future<Uint8List> compressPDF(
    Uint8List pdfFile, {
    PdfCompressionMode mode = PdfCompressionMode.auto,
    double minAcceptableReductionPercent = 10,
  }) async {
    final result = await compressPDFWithStats(
      pdfFile,
      mode: mode,
      minAcceptableReductionPercent: minAcceptableReductionPercent,
    );
    return result.bytes;
  }

  // ============ 4. UNIVERSAL CONVERTER ============

  // 1. Text (.txt) -> PDF
  static Future<Uint8List> convertTextToPDF(Uint8List textBytes) async {
    final text = utf8.decode(textBytes, allowMalformed: true);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: p.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Paragraph(
            text: text,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  // 2. Excel (.xlsx) -> PDF
  static Future<Uint8List> convertExcelToPDF(Uint8List excelBytes) async {
    final excel = ex.Excel.decodeBytes(excelBytes);
    final pdf = pw.Document();

    for (var table in excel.tables.keys) {
      final currentSheet = excel.tables[table];
      if (currentSheet == null || currentSheet.rows.isEmpty) continue;

      // Extract table rows
      final List<List<String>> tableData = [];
      for (var row in currentSheet.rows) {
        final rowData =
            row.map((cell) => cell?.value?.toString() ?? '').toList();
        tableData.add(rowData);
      }

      if (tableData.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat:
                p.PdfPageFormat.a4.landscape, // Excel data ke liye landscape
            margin: const pw.EdgeInsets.all(24),
            header: (context) => pw.Header(
              level: 0,
              child: pw.Text('Sheet: $table',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ),
            build: (context) => [
              pw.TableHelper.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: p.PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: p.PdfColors.blueGrey700),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        );
      }
    }

    return await pdf.save();
  }

  // 3. Image (JPG, PNG) -> PDF (Existing Updated)
  static Future<Uint8List> convertImageToPDF(Uint8List imageData) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageData);

    pdf.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );

    return await pdf.save();
  }

  /// Same as [compressPDF] but also returns before/after size stats, so you
  /// can log or display exactly what happened (originalSizeBytes,
  /// compressedSizeBytes, reductionPercent, strategyUsed).
  ///
  /// IMPORTANT BEHAVIOUR CHANGE from the previous version: this no longer
  /// skips rasterization just because the PDF looks text/vector-based.
  /// Skipping it meant that for most everyday PDFs — which are already
  /// Flate-compressed by whatever tool made them — the "lossless" pass
  /// saved almost nothing, and the function looked like it was doing
  /// nothing at all. Now:
  ///   1. It always tries the cheap lossless stream-compression pass first.
  ///   2. If that doesn't shrink the file by at least
  ///      [minAcceptableReductionPercent] (default 10%), OR the document
  ///      looks scanned/image-heavy, OR an explicit non-auto `mode` was
  ///      requested, it escalates to rasterization.
  ///   3. Text-heavy documents get a *gentle* rasterization profile (higher
  ///      resolution + quality) so text stays legible; scanned/image-heavy
  ///      documents get progressively more aggressive profiles.
  ///   4. Whatever attempt produced the smallest file wins. The original is
  ///      only returned untouched if literally nothing beat it.
  static Future<PdfCompressionResult> compressPDFWithStats(
    Uint8List pdfFile, {
    PdfCompressionMode mode = PdfCompressionMode.auto,
    double minAcceptableReductionPercent = 10,
  }) async {
    try {
      final info = await analyzePdf(pdfFile);
      final bool looksScanned = info['looksScanned'] as bool;

      Uint8List best = pdfFile;
      String strategy = 'none (already optimal)';

      // Step 1: cheap, always-safe pass.
      final Uint8List lossless = await _compressLossless(pdfFile);
      if (lossless.length < best.length) {
        best = lossless;
        strategy = 'lossless stream compression';
      }

      final int safeOriginalLen = pdfFile.length > 0 ? pdfFile.length : 1;
      final double reductionSoFar = 1 - (best.length / safeOriginalLen);

      final bool needsMoreWork =
          reductionSoFar < (minAcceptableReductionPercent / 100) ||
              looksScanned ||
              mode != PdfCompressionMode.auto;

      if (needsMoreWork) {
        final List<_RasterProfile> attempts =
            _buildAttemptChain(mode, info, looksScanned);

        for (final profile in attempts) {
          final Uint8List candidate =
              await _compressByRasterizing(pdfFile, profile);
          if (candidate.length < best.length) {
            best = candidate;
            strategy = 'rasterized ($profile)';
          }
          // Stop early once we've shaved at least ~15% off the original.
          if (best.length <= (pdfFile.length * 0.85).round()) {
            break;
          }
        }
      }

      final double finalReduction = 1 - (best.length / safeOriginalLen);

      return PdfCompressionResult(
        bytes: best,
        originalSizeBytes: pdfFile.length,
        compressedSizeBytes: best.length,
        reductionPercent: (finalReduction * 100).clamp(0, 100),
        strategyUsed: strategy,
        looksScanned: looksScanned,
      );
    } catch (e) {
      throw Exception('Failed to compress PDF: $e');
    }
  }

  /// Inspects the PDF without fully rendering it, and returns a cheap
  /// classification used to decide the compression strategy.
  static Future<Map<String, dynamic>> analyzePdf(Uint8List pdfFile) async {
    final PdfDocument doc = PdfDocument(inputBytes: pdfFile);
    final int pageCount = doc.pages.count;
    doc.dispose();

    final double bytesPerPage =
        pageCount > 0 ? pdfFile.length / pageCount : pdfFile.length.toDouble();

    // Heuristic: real scanned/photographed pages (even reasonably
    // compressed ones) rarely go below ~150KB/page at usable resolution.
    // Pure text/vector pages are almost always far smaller than that,
    // even with a handful of small logos or diagrams.
    final bool looksScanned = bytesPerPage > 150 * 1024;

    return {
      'pages': pageCount,
      'sizeBytes': pdfFile.length,
      'bytesPerPage': bytesPerPage,
      'looksScanned': looksScanned,
    };
  }

  /// Builds an ordered list of rasterization profiles to try, from the
  /// gentlest that should work up to the most aggressive, based on the
  /// requested mode and/or the document's own density.
  static List<_RasterProfile> _buildAttemptChain(
    PdfCompressionMode mode,
    Map<String, dynamic> info,
    bool looksScanned,
  ) {
    if (mode != PdfCompressionMode.auto) {
      switch (mode) {
        case PdfCompressionMode.high:
          return const [_RasterProfile(1800, 82), _RasterProfile(1400, 70)];
        case PdfCompressionMode.medium:
          return const [_RasterProfile(1300, 65), _RasterProfile(1000, 50)];
        case PdfCompressionMode.low:
          return const [_RasterProfile(950, 45), _RasterProfile(750, 32)];
        case PdfCompressionMode.extreme:
          return const [_RasterProfile(650, 28), _RasterProfile(500, 20)];
        case PdfCompressionMode.auto:
          break; // unreachable, handled below
      }
    }

    if (!looksScanned) {
      // Text/vector-dominant document: keep it legible. High resolution +
      // high JPEG quality still shrinks most bloated "everyday" PDFs
      // (embedded fonts, unused metadata, uncompressed images) noticeably,
      // without turning text visibly blurry.
      return const [_RasterProfile(1800, 82), _RasterProfile(1500, 72)];
    }

    // AUTO + scanned/image-heavy: pick a starting point from how "heavy"
    // the document already is, with a fallback step in the chain.
    final double bpp = info['bytesPerPage'] as double;
    if (bpp > 1200 * 1024) {
      return const [_RasterProfile(700, 35), _RasterProfile(500, 22)];
    } else if (bpp > 600 * 1024) {
      return const [_RasterProfile(900, 45), _RasterProfile(700, 32)];
    } else if (bpp > 300 * 1024) {
      return const [_RasterProfile(1100, 55), _RasterProfile(850, 40)];
    } else {
      // Already fairly light scans — be gentle, just clean up a bit.
      return const [_RasterProfile(1400, 70), _RasterProfile(1100, 55)];
    }
  }

  /// Re-saves the PDF with Syncfusion's best stream compression, without
  /// touching page content visually. Safe for text/vector-heavy PDFs.
  static Future<Uint8List> _compressLossless(Uint8List pdfFile) async {
    try {
      final PdfDocument doc = PdfDocument(inputBytes: pdfFile);
      doc.compressionLevel = PdfCompressionLevel.best;
      final List<int> bytes = doc.saveSync();
      doc.dispose();
      return Uint8List.fromList(bytes);
    } catch (_) {
      return pdfFile;
    }
  }

  /// Rasterizes every page to a JPEG at the given profile's resolution and
  /// quality, then rebuilds a PDF from those images. Never upscales a page
  /// beyond its own native width.
  static Future<Uint8List> _compressByRasterizing(
    Uint8List pdfFile,
    _RasterProfile profile,
  ) async {
    try {
      final px.PdfDocument document = await px.PdfDocument.openData(pdfFile);
      final pw.Document compressedPdf = pw.Document();

      for (int i = 1; i <= document.pagesCount; i++) {
        final px.PdfPage page = await document.getPage(i);

        // Never upscale — only shrink if the page is wider than our target.
        double scale = 1.0;
        if (page.width > profile.maxWidth) {
          scale = profile.maxWidth / page.width;
        }

        final renderWidth = (page.width * scale).roundToDouble();
        final renderHeight = (page.height * scale).roundToDouble();

        final px.PdfPageImage? pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: px.PdfPageImageFormat.jpeg,
        );

        await page.close();

        if (pageImage != null) {
          final img.Image? decodedImage = img.decodeImage(pageImage.bytes);
          if (decodedImage != null) {
            final Uint8List compressedImageBytes = Uint8List.fromList(
              img.encodeJpg(decodedImage, quality: profile.jpegQuality),
            );

            final imageProvider = pw.MemoryImage(compressedImageBytes);
            compressedPdf.addPage(
              pw.Page(
                pageFormat: p.PdfPageFormat(page.width, page.height),
                margin: pw.EdgeInsets.zero,
                build: (pw.Context context) {
                  return pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Image(imageProvider, fit: pw.BoxFit.fill),
                  );
                },
              ),
            );
          }
        }
      }

      await document.close();
      return await compressedPdf.save();
    } catch (_) {
      return pdfFile; // signal "no improvement" to the caller
    }
  }

  // ============ 4. CONVERT IMAGE TO PDF ============
  static Future<Uint8List> convertToPDF(Uint8List imageData) async {
    try {
      final pdf = pw.Document();
      final image = pw.MemoryImage(imageData);

      pdf.addPage(
        pw.Page(
          pageFormat: p.PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(image),
          ),
        ),
      );

      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to convert to PDF: $e');
    }
  }

  // ============ 5. ROTATE PDF ============
  static Future<Uint8List> rotatePDF(Uint8List pdfFile, int degrees) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfFile);

      PdfPageRotateAngle angle;
      switch (degrees % 360) {
        case 90:
          angle = PdfPageRotateAngle.rotateAngle90;
          break;
        case 180:
          angle = PdfPageRotateAngle.rotateAngle180;
          break;
        case 270:
          angle = PdfPageRotateAngle.rotateAngle270;
          break;
        default:
          angle = PdfPageRotateAngle.rotateAngle0;
      }

      for (int i = 0; i < document.pages.count; i++) {
        document.pages[i].rotation = angle;
      }

      final List<int> bytes = document.saveSync();
      document.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to rotate PDF: $e');
    }
  }

  // ============ 6. UNLOCK PDF ============
  static Future<Uint8List> unlockPDF(Uint8List pdfFile, String password) async {
    try {
      final PdfDocument document = PdfDocument(
        inputBytes: pdfFile,
        password: password,
      );

      document.security.permissions.clear();

      final List<int> bytes = document.saveSync();
      document.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to unlock PDF: $e');
    }
  }

// ============ 7. ADD WATERMARK (IN BACKGROUND) ============
  static Future<Uint8List> addWatermark(
    Uint8List pdfFile,
    String text, {
    double opacity = 0.25,
  }) async {
    try {
      final PdfDocument inputDocument = PdfDocument(inputBytes: pdfFile);
      final PdfDocument outputDocument = PdfDocument();

      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 50);
      final PdfBrush brush = PdfSolidBrush(
        PdfColor(180, 180, 180, (opacity * 255).round()),
      );

      for (int i = 0; i < inputDocument.pages.count; i++) {
        final PdfPage originalPage = inputDocument.pages[i];
        final Size pageSize = originalPage.getClientSize();

        // 1. Output document mein naya page add karein
        final PdfPage newPage = outputDocument.pages.add();

        // 2. PEHLE WATERMARK DRAW KAREIN (Background Layer)
        final Size textSize = font.measureString(text);
        newPage.graphics.save();
        newPage.graphics
            .translateTransform(pageSize.width / 2, pageSize.height / 2);
        newPage.graphics.rotateTransform(-45);
        newPage.graphics.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            -textSize.width / 2,
            -textSize.height / 2,
            textSize.width,
            textSize.height,
          ),
        );
        newPage.graphics.restore();

        // 3. BAAD MEIN ORIGINAL CONTENT DRAW KAREIN (Foreground Layer)
        // Original page ka text/images watermark ke upar aayega
        final PdfTemplate template = originalPage.createTemplate();
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          pageSize,
        );
      }

      inputDocument.dispose();

      final List<int> bytes = outputDocument.saveSync();
      outputDocument.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to add watermark: $e');
    }
  }

  // ============ Helper: Generate Page Thumbnails ============
  static Future<List<Uint8List>> getPageThumbnails(Uint8List pdfFile) async {
    final List<Uint8List> thumbnails = [];
    try {
      final px.PdfDocument document = await px.PdfDocument.openData(pdfFile);

      for (int i = 1; i <= document.pagesCount; i++) {
        final px.PdfPage page = await document.getPage(i);

        // Thumbnail ke liye 200px width kaafi hoti hai (fast render)
        double scale = 200 / page.width;
        final px.PdfPageImage? pageImage = await page.render(
          width: (page.width * scale).roundToDouble(),
          height: (page.height * scale).roundToDouble(),
          format: px.PdfPageImageFormat.jpeg,
        );

        await page.close();

        if (pageImage != null) {
          thumbnails.add(pageImage.bytes);
        }
      }

      await document.close();
    } catch (e) {
      print('Error generating thumbnails: $e');
    }
    return thumbnails;
  }

  // ============ 8. ORGANIZE PAGES ============
  static Future<Uint8List> organizePages(
    Uint8List pdfFile,
    List<int> newOrder,
  ) async {
    try {
      final PdfDocument inputPdf = PdfDocument(inputBytes: pdfFile);
      final PdfDocument outputPdf = PdfDocument();

      for (final index in newOrder) {
        if (index >= 0 && index < inputPdf.pages.count) {
          final PdfTemplate template = inputPdf.pages[index].createTemplate();
          final PdfPage page = outputPdf.pages.add();
          page.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            page.getClientSize(),
          );
        }
      }

      inputPdf.dispose();
      final List<int> bytes = outputPdf.saveSync();
      outputPdf.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to organize pages: $e');
    }
  }

  // ============ Helper: Get PDF Info ============
  static Future<Map<String, dynamic>> getPDFInfo(Uint8List pdfFile) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfFile);
      final count = document.pages.count;
      document.dispose();

      return {
        'pages': count,
        'size': (pdfFile.length / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      return {'pages': 0, 'size': '0'};
    }
  }
}
