import 'package:flutter/material.dart';

class PDFTool {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;

  PDFTool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
  });

  static List<PDFTool> getTools() {
    return [
      PDFTool(
        id: 'merge',
        title: 'Merge PDF',
        description: 'Combine multiple PDFs into one',
        icon: Icons.merge_type,
        color: const Color(0xFF2563EB),
        route: '/merge',
      ),
      PDFTool(
        id: 'split',
        title: 'Split PDF',
        description: 'Split PDF into multiple files',
        icon: Icons.call_split,
        color: const Color(0xFF7C3AED),
        route: '/split',
      ),
      PDFTool(
        id: 'compress',
        title: 'Compress PDF',
        description: 'Reduce PDF file size',
        icon: Icons.compress,
        color: const Color(0xFFEC4899),
        route: '/compress',
      ),
      PDFTool(
        id: 'convert',
        title: 'Convert PDF',
        description: 'Convert to/from PDF formats',
        icon: Icons.transform,
        color: const Color(0xFFF59E0B),
        route: '/convert',
      ),
      PDFTool(
        id: 'rotate',
        title: 'Rotate PDF',
        description: 'Rotate PDF pages',
        icon: Icons.rotate_right,
        color: const Color(0xFF10B981),
        route: '/rotate',
      ),
      PDFTool(
        id: 'unlock',
        title: 'Unlock PDF',
        description: 'Remove PDF password',
        icon: Icons.lock_open,
        color: const Color(0xFFEF4444),
        route: '/unlock',
      ),
      PDFTool(
        id: 'watermark',
        title: 'Add Watermark',
        description: 'Add text or image watermark',
        icon: Icons.water,
        color: const Color(0xFF8B5CF6),
        route: '/watermark',
      ),
      PDFTool(
        id: 'organize',
        title: 'Organize Pages',
        description: 'Rearrange PDF pages',
        icon: Icons.view_agenda,
        color: const Color(0xFF06B6D4),
        route: '/organize',
      ),
    ];
  }
}