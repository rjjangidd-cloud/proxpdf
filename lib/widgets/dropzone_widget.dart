import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:provider/provider.dart';
import 'package:proxpdf/providers/pdf_provider.dart';
import 'package:proxpdf/utils/responsive_utils.dart';
import 'dart:typed_data';
//import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

class DropzoneWidget extends StatefulWidget {
  const DropzoneWidget({super.key});

  @override
  State<DropzoneWidget> createState() => _DropzoneWidgetState();
}

class _DropzoneWidgetState extends State<DropzoneWidget> {
  late DropzoneViewController controller;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final provider = Provider.of<PDFProvider>(context);

    return Container(
      height: isMobile ? 200 : 260,
      decoration: BoxDecoration(
        color: _isDragging ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDragging ? Colors.blue.shade400 : Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          if (!isMobile)
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: isMobile
          ? _buildMobileUpload(context, provider)
          : _buildWebDropzone(context, provider),
    );
  }

  // ==================== WEB DROPZONE ====================
  Widget _buildWebDropzone(BuildContext context, PDFProvider provider) {
    return Stack(
      children: [
        // 1. Invisible HTML Native Drop Area (Fills Entire Container)
        Positioned.fill(
          child: DropzoneView(
            operation: DragOperation.copy,
            cursor: CursorType.grab,
            onCreated: (ctrl) => controller = ctrl,
            onHover: () => setState(() => _isDragging = true),
            onLeave: () => setState(() => _isDragging = false),
            // Use onDropFiles to handle single or multiple dropped files reliably
            onDropFiles: (List<dynamic>? files) async {
              setState(() => _isDragging = false);
              if (files == null || files.isEmpty) return;

              int successCount = 0;
              for (final file in files) {
                try {
                  final name = await controller.getFilename(file);
                  if (name.toLowerCase().endsWith('.pdf')) {
                    final data = await controller.getFileData(file);
                    provider.addFile(data);
                    successCount++;
                  }
                } catch (e) {
                  debugPrint('Error reading dropped file: $e');
                }
              }

              if (successCount > 0 && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '✅ $successCount PDF file(s) loaded successfully!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please drop valid .pdf files'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ),

        // 2. Visible UI (Wrapped in IgnorePointer so mouse events pass to DropzoneView)
        IgnorePointer(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isDragging
                      ? Icons.file_download_outlined
                      : Icons.cloud_upload_outlined,
                  size: 56,
                  color:
                      _isDragging ? Colors.blue.shade600 : Colors.blue.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  _isDragging
                      ? 'Drop your PDF files here!'
                      : 'Drag & Drop PDF files here',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _isDragging
                        ? Colors.blue.shade700
                        : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Supports multiple files for Merge and Split',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                if (provider.uploadedFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '${provider.uploadedFiles.length} file(s) currently ready',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== MOBILE UPLOAD ====================
  Widget _buildMobileUpload(BuildContext context, PDFProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_file,
            size: 48,
            color: Colors.blue.shade400,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                // FilePicker Web, Android aur iOS sab par natively chalta hai
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                  allowMultiple: true,
                  withData:
                      true, // Sabse important: Web aur Mobile dono par bytes return karta hai
                );

                if (result != null && result.files.isNotEmpty) {
                  for (var platformFile in result.files) {
                    final bytes = platformFile.bytes;
                    if (bytes != null) {
                      provider.addFile(bytes);
                    }
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('File uploaded successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          if (provider.uploadedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${provider.uploadedFiles.length} file(s) uploaded',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
