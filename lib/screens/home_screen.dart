import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proxpdf/providers/pdf_provider.dart';
import 'package:proxpdf/providers/auth_provider.dart';
import 'package:proxpdf/widgets/tool_card.dart';
import 'package:proxpdf/widgets/dropzone_widget.dart';
import 'package:proxpdf/widgets/file_list_widget.dart';
import 'package:proxpdf/utils/theme_utils.dart';
import 'package:proxpdf/utils/file_saver.dart';
import 'package:proxpdf/services/pdf_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import 'package:proxpdf/widgets/web_app_bar.dart' as web_widgets;
import 'package:proxpdf/widgets/mobile_app_bar.dart' as mobile_widgets;

// NOTE: MobileDrawer's current constructor takes no params (just `key`), so
// it can't be customized with tools/logout from here yet. The drawer below
// is built directly in this file instead. MobileAppBar's real signature
// (title, actions, onMenuTap) IS used as-is - see appBar below.

/// Central place for breakpoints so every widget in this file agrees
/// on what counts as "mobile" / "tablet" / "desktop".
class _Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Single LayoutBuilder driving the whole screen so every child gets
    // consistent, live width info (also updates correctly on rotation /
    // browser window resize, unlike a one-off MediaQuery read).
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < _Breakpoints.mobile;
        final isTablet =
            width >= _Breakpoints.mobile && width < _Breakpoints.tablet;

        return _HomeScreenBody(
          isMobile: isMobile,
          isTablet: isTablet,
          width: width,
        );
      },
    );
  }
}

class _HomeScreenBody extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;
  final double width;

  const _HomeScreenBody({
    required this.isMobile,
    required this.isTablet,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final provider = Provider.of<PDFProvider>(context, listen: false);

    // Responsive tokens used everywhere below.
    final double horizontalPadding = isMobile ? 16 : (isTablet ? 24 : 40);
    final double heroPadding = isMobile ? 20 : (isTablet ? 32 : 48);
    final int gridColumns = isMobile ? 2 : (isTablet ? 3 : 4);
    final double gridSpacing = isMobile ? 12 : (isTablet ? 16 : 20);
    final double gridAspectRatio = isMobile ? 0.85 : 1;

    late final PreferredSizeWidget appBar;
    if (isMobile) {
      appBar = mobile_widgets.MobileAppBar(
        title: 'ProxPDF',
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context, auth),
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
          ),
        ],
      );
    } else {
      appBar = web_widgets.WebAppBar(
        title: 'ProxPDF',
        onToolSelected: (toolId) async {
          final selectedTool = provider.tools.firstWhere((t) => t.id == toolId);
          await _handleToolTap(context, provider, selectedTool);
        },
        actions: [
          _UserBadge(auth: auth),
          IconButton(
            onPressed: () => _showLogoutDialog(context, auth),
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
          ),
        ],
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: isMobile ? _buildMobileDrawer(context, auth, provider) : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isMobile ? 16 : 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isMobile ? 12 : 20),
                _buildHeroSection(context, heroPadding),
                SizedBox(height: isMobile ? 28 : 50),
                _buildToolsSection(
                  context,
                  gridColumns: gridColumns,
                  gridSpacing: gridSpacing,
                  gridAspectRatio: gridAspectRatio,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(
      BuildContext context, AuthProvider auth, PDFProvider provider) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      auth.currentUser.isNotEmpty
                          ? auth.currentUser[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      auth.currentUser.split('@').first,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: provider.tools.length,
                itemBuilder: (context, index) {
                  final tool = provider.tools[index];
                  return ListTile(
                    leading: Icon(tool.icon, color: tool.color),
                    title: Text(
                      tool.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      tool.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    onTap: () async {
                      Navigator.pop(context); // close drawer first
                      await _handleToolTap(context, provider, tool);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // close drawer first
                _showLogoutDialog(context, auth);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, double heroPadding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(heroPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: isMobile ? 44 : 60,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Everything You Need to\nWork with PDFs',
            style: (isMobile ? AppTextStyles.heading2 : AppTextStyles.heading1)
                .copyWith(
              fontSize: isMobile ? 22 : null,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: const [AppColors.primary, AppColors.secondary],
                ).createShader(
                    Rect.fromLTWH(0, 0, isMobile ? width : 400, 100)),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isMobile
                ? 'Merge • Split • Compress • Convert\nRotate • Unlock • Watermark • Organize'
                : 'Merge • Split • Compress • Convert • Rotate • Unlock • Watermark • Organize',
            style:
                (isMobile ? AppTextStyles.bodyMedium : AppTextStyles.bodyLarge)
                    .copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 20 : 32),
          const DropzoneWidget(),
          const FileListWidget(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildActionChip(Icons.upload_file, 'Upload', Colors.blue),
              _buildActionChip(Icons.folder_open, 'Browse', Colors.purple),
              _buildActionChip(Icons.link, 'From URL', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, Color color) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: TextStyle(color: color),
      ),
      onPressed: () {},
      backgroundColor: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildToolsSection(
    BuildContext context, {
    required int gridColumns,
    required double gridSpacing,
    required double gridAspectRatio,
  }) {
    final provider = Provider.of<PDFProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All PDF Tools', style: AppTextStyles.heading2),
                  const SizedBox(height: 4),
                  Text(
                    'Select a tool to get started',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: Colors.grey.shade600),
                  ),
                  if (provider.uploadedFiles.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _FilesLoadedBadge(count: provider.uploadedFiles.length),
                  ],
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All PDF Tools', style: AppTextStyles.heading2),
                      const SizedBox(height: 4),
                      Text(
                        'Select a tool to get started',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (provider.uploadedFiles.isNotEmpty)
                    _FilesLoadedBadge(count: provider.uploadedFiles.length),
                ],
              ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: gridAspectRatio,
          ),
          itemCount: provider.tools.length,
          itemBuilder: (context, index) {
            final tool = provider.tools[index];
            return ToolCard(
              tool: tool,
              onTap: () async {
                await _handleToolTap(context, provider, tool);
              },
            );
          },
        ),
      ],
    );
  }

  // ==================== TOOL HANDLING (unchanged logic) ====================

  Future<void> _handleToolTap(
      BuildContext context, PDFProvider provider, tool) async {
    provider.setSelectedTool(tool.id);

    if (provider.uploadedFiles.isEmpty) {
      await _pickPDFFiles(context, provider, tool.id);
      return;
    }

    await _processTool(context, provider, tool.id);
  }

  Future<void> _pickPDFFiles(
      BuildContext context, PDFProvider provider, String toolId) async {
    try {
      final bool allowMultiple = toolId == 'merge' || toolId == 'organize';

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        provider.clearFiles();
        for (var file in result.files) {
          if (file.bytes != null) {
            provider.addFile(file.bytes!);
          }
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result.files.length} PDF file(s) loaded'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        await _processTool(context, provider, toolId);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files selected'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processTool(
      BuildContext context, PDFProvider provider, String toolId) async {
    switch (toolId) {
      case 'merge':
        await _processMerge(context, provider);
        break;
      case 'split':
        await _processSplit(context, provider);
        break;
      case 'compress':
        await _processCompress(context, provider);
        break;
      case 'convert':
        await _processConvert(context, provider);
        break;
      case 'rotate':
        await _processRotate(context, provider);
        break;
      case 'unlock':
        await _processUnlock(context, provider);
        break;
      case 'watermark':
        await _processWatermark(context, provider);
        break;
      case 'organize':
        await _processOrganize(context, provider);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${toolId.toUpperCase()} coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
    }
  }

  // ============ 1. MERGE ============
  Future<void> _processMerge(BuildContext context, PDFProvider provider) async {
    if (provider.uploadedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 PDF files to merge'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showProcessingDialog(
        context, 'Merging ${provider.uploadedFiles.length} PDF files...');

    try {
      final mergedPDF = await PDFService.mergePDFs(provider.uploadedFiles);
      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(context, mergedPDF, 'PDF Merged Successfully!');
      provider.clearFiles();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  // ============ 2. SPLIT ============
  Future<void> _processSplit(BuildContext context, PDFProvider provider) async {
    if (provider.uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file to split'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showProcessingDialog(context, 'Splitting PDF...');

    try {
      final splitFiles =
          await PDFService.splitPDF(provider.uploadedFiles.first);
      if (!context.mounted) return;
      Navigator.pop(context);
      _showSplitSuccessDialog(context, splitFiles);
      provider.clearFiles();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  // ============ 3. COMPRESS ============
  Future<void> _processCompress(
      BuildContext context, PDFProvider provider) async {
    if (provider.uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file to compress'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showProcessingDialog(context, 'Compressing PDF...');

    try {
      final compressedPDF =
          await PDFService.compressPDF(provider.uploadedFiles.first);
      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(
          context, compressedPDF, 'PDF Compressed Successfully!');
      provider.clearFiles();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  // ============ 4. CONVERT ============
  Future<void> _processConvert(
      BuildContext context, PDFProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'txt', 'xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No file selected'),
              backgroundColor: Colors.orange),
        );
        return;
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase();
      final fileBytes = file.bytes;

      if (fileBytes == null) {
        _showErrorDialog(context, 'Unable to read file data');
        return;
      }

      _showProcessingDialog(context, 'Converting ${file.name} to PDF...');

      Uint8List convertedPDF;
      if (['jpg', 'jpeg', 'png'].contains(extension)) {
        convertedPDF = await PDFService.convertImageToPDF(fileBytes);
      } else if (extension == 'txt') {
        convertedPDF = await PDFService.convertTextToPDF(fileBytes);
      } else if (extension == 'xlsx') {
        convertedPDF = await PDFService.convertExcelToPDF(fileBytes);
      } else {
        if (!context.mounted) return;
        Navigator.pop(context);
        _showErrorDialog(context, 'Unsupported format');
        return;
      }

      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(
        context,
        convertedPDF,
        'Converted to PDF Successfully!',
        defaultFileName: '${file.name.split('.').first}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, 'Conversion failed: ${e.toString()}');
    }
  }

  // ============ 5. ROTATE ============
  Future<void> _processRotate(
      BuildContext context, PDFProvider provider) async {
    if (provider.uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file to rotate'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final degrees = await _showRotateDialog(context);
    if (degrees == null) return;

    _showProcessingDialog(context, 'Rotating PDF...');

    try {
      final rotatedPDF =
          await PDFService.rotatePDF(provider.uploadedFiles.first, degrees);
      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(context, rotatedPDF, 'PDF Rotated ${degrees}°!');
      provider.clearFiles();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  // ============ 6. UNLOCK ============
  Future<void> _processUnlock(
      BuildContext context, PDFProvider provider) async {
    if (provider.uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file to unlock'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final password = await _showPasswordDialog(context);
    if (password == null) return;

    _showProcessingDialog(context, 'Unlocking PDF...');

    try {
      final unlockedPDF =
          await PDFService.unlockPDF(provider.uploadedFiles.first, password);
      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(context, unlockedPDF, 'PDF Unlocked Successfully!');
      provider.clearFiles();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  // ============ 7. WATERMARK ============
  Future<void> _processWatermark(
      BuildContext context, PDFProvider provider) async {
    if (provider.uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file to watermark'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final watermarkText = await _showWatermarkDialog(context);
    if (watermarkText == null || watermarkText.isEmpty) return;

    _showProcessingDialog(context, 'Adding watermark...');

    try {
      final watermarkedPDF = await PDFService.addWatermark(
        provider.uploadedFiles.first,
        watermarkText,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(context, watermarkedPDF, 'Watermark Added!');
      provider.clearFiles();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  // ============ 8. ORGANIZE ============
  Future<void> _processOrganize(
      BuildContext context, PDFProvider provider) async {
    if (provider.uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file to organize'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newOrder = await showDialog<List<int>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OrganizePagesDialog(
        pdfBytes: provider.uploadedFiles.first,
      ),
    );

    if (newOrder == null) return;

    _showProcessingDialog(context, 'Reordering pages...');

    try {
      final organizedPDF = await PDFService.organizePages(
        provider.uploadedFiles.first,
        newOrder,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(
        context,
        organizedPDF,
        'Pages Organized Successfully!',
        defaultFileName: 'organized.pdf',
      );
      provider.clearFiles();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  // ==================== DIALOGS (now width-aware) ====================

  /// Clamp a dialog's width so it never overflows a narrow phone screen,
  /// while still looking sensible (not full-bleed) on tablets/desktop.
  double _dialogWidth(BuildContext context, {double max = 420}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return math.min(max, screenWidth * 0.9);
  }

  void _showProcessingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: _dialogWidth(context, max: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context,
    Uint8List pdfData,
    String title, {
    String defaultFileName = 'output.pdf',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Size: ${(pdfData.length / 1024).toStringAsFixed(2)} KB',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await FileSaver.downloadFile(
                pdfData,
                defaultFileName,
                context: context,
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showSplitSuccessDialog(
      BuildContext context, List<Uint8List> splitFiles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Split Complete!'),
          ],
        ),
        content: SizedBox(
          width: _dialogWidth(context, max: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_zip, size: 50, color: Colors.purple),
              const SizedBox(height: 12),
              Text(
                'PDF split into ${splitFiles.length} pages',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: splitFiles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final fileBytes = splitFiles[index];
                    final fileName = 'split_page_${index + 1}.pdf';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Page ${index + 1}'),
                      subtitle: Text(
                        '${(fileBytes.length / 1024).toStringAsFixed(2)} KB',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download,
                            color: AppColors.primary),
                        tooltip: 'Download this page',
                        onPressed: () async {
                          await FileSaver.downloadFile(
                            fileBytes,
                            fileName,
                            context: context,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await FileSaver.downloadZip(
                splitFiles,
                'split_pages.zip',
                context: context,
                filePrefix: 'split_page',
              );
            },
            icon: const Icon(Icons.archive),
            label: const Text('Download All as ZIP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Text(error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showRotateDialog(BuildContext context) async {
    int selected = 90;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rotate PDF'),
        content: SizedBox(
          width: _dialogWidth(context, max: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select rotation angle:'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [90, 180, 270].map((angle) {
                  return ChoiceChip(
                    label: Text('$angle°'),
                    selected: selected == angle,
                    onSelected: (_) {
                      selected = angle;
                      Navigator.pop(context, angle);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected == angle ? Colors.white : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unlock PDF'),
        content: SizedBox(
          width: _dialogWidth(context, max: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter PDF password:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showWatermarkDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Watermark'),
        content: SizedBox(
          width: _dialogWidth(context, max: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter watermark text:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Watermark Text',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add Watermark'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: SizedBox(
          width: _dialogWidth(context, max: 320),
          child: const Text('Are you sure you want to logout?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              auth.logout();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

/// Small user avatar + name chip, reused in the desktop app bar and (in a
/// compact form) inline on mobile where the app bar has no room for it.
class _UserBadge extends StatelessWidget {
  final AuthProvider auth;
  final bool compact;

  const _UserBadge({required this.auth, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              auth.currentUser.isNotEmpty
                  ? auth.currentUser[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              auth.currentUser.split('@').first,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilesLoadedBadge extends StatelessWidget {
  final int count;
  const _FilesLoadedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        '$count files loaded',
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ==================== ORGANIZE PAGES DIALOG (responsive) ====================

class OrganizePagesDialog extends StatefulWidget {
  final Uint8List pdfBytes;

  const OrganizePagesDialog({super.key, required this.pdfBytes});

  @override
  State<OrganizePagesDialog> createState() => _OrganizePagesDialogState();
}

class _OrganizePagesDialogState extends State<OrganizePagesDialog> {
  bool _isLoading = true;
  List<Uint8List> _thumbnails = [];
  List<int> _order = [];

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    final images = await PDFService.getPageThumbnails(widget.pdfBytes);
    if (!mounted) return;
    setState(() {
      _thumbnails = images;
      _order = List.generate(images.length, (index) => index);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < _Breakpoints.mobile;

    // On phones use almost the full screen; on tablet/desktop keep the
    // original fixed-ish size, capped so it never exceeds the viewport.
    final dialogWidth = isMobile
        ? screenSize.width * 0.95
        : math.min(650.0, screenSize.width * 0.9);
    final dialogHeight = isMobile
        ? screenSize.height * 0.75
        : math.min(450.0, screenSize.height * 0.8);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 24,
      ),
      title: Row(
        children: [
          const Icon(Icons.view_module, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMobile ? 'Organize Pages' : 'Organize Pages (Drag & Drop)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      contentPadding:
          EdgeInsets.fromLTRB(isMobile ? 8 : 24, 20, isMobile ? 8 : 24, 24),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Rendering page previews...'),
                  ],
                ),
              )
            : ReorderableListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: _order.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex--;
                    final item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, visualIndex) {
                  final originalIndex = _order[visualIndex];
                  final imageBytes = _thumbnails[originalIndex];

                  return Card(
                    key: ValueKey('page_$originalIndex'),
                    elevation: 3,
                    margin: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: isMobile ? 2 : 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 8 : 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: isMobile ? 13 : 16,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              '${visualIndex + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 11 : 13,
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 10 : 16),
                          Container(
                            height: isMobile ? 70 : 100,
                            width: isMobile ? 52 : 75,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 10 : 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Original Page ${originalIndex + 1}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 13 : 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isMobile
                                      ? 'To position ${visualIndex + 1}'
                                      : 'Moving to Position ${visualIndex + 1}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: isMobile ? 11 : 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.drag_indicator,
                            color: Colors.grey,
                            size: isMobile ? 22 : 28,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actionsPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 8,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, _order),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply Order'),
        ),
      ],
    );
  }
}
