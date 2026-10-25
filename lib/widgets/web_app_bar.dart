import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proxpdf/providers/pdf_provider.dart';

class WebAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Function(String toolId)? onToolSelected; // Callback for tool selection

  const WebAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onToolSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final pdfProvider = Provider.of<PDFProvider>(context);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      titleSpacing: 24,
      title: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 32),

          // ============ TOOLS DROPDOWN MENU ============
          PopupMenuButton<String>(
            tooltip: 'All PDF Tools',
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (toolId) {
              if (onToolSelected != null) {
                onToolSelected!(toolId);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_outlined, size: 18, color: Colors.black87),
                  SizedBox(width: 8),
                  Text(
                    'Tools',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      size: 18, color: Colors.black87),
                ],
              ),
            ),
            itemBuilder: (BuildContext context) {
              return pdfProvider.tools.map((tool) {
                return PopupMenuItem<String>(
                  value: tool.id,
                  child: Row(
                    children: [
                      Icon(tool.icon, color: tool.color, size: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tool.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            tool.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      actions: actions,
    );
  }
}
