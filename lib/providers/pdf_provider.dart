import 'package:flutter/material.dart';
import 'package:proxpdf/models/pdf_tool.dart';
import 'dart:typed_data';

class PDFProvider extends ChangeNotifier {
  List<PDFTool> _tools = PDFTool.getTools();
  List<Uint8List> _uploadedFiles = [];
  bool _isProcessing = false;
  String _selectedTool = '';

  List<PDFTool> get tools => _tools;
  List<Uint8List> get uploadedFiles => _uploadedFiles;
  bool get isProcessing => _isProcessing;
  String get selectedTool => _selectedTool;

  void setSelectedTool(String toolId) {
    _selectedTool = toolId;
    notifyListeners();
  }

  void addFile(Uint8List fileBytes) {
    _uploadedFiles.add(fileBytes);
    notifyListeners();
  }

  void removeFile(int index) {
    _uploadedFiles.removeAt(index);
    notifyListeners();
  }

  void clearFiles() {
    _uploadedFiles.clear();
    notifyListeners();
  }

  void setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  Future<void> processPDF(String toolId) async {
    setProcessing(true);
    try {
      // Simulate processing
      await Future.delayed(const Duration(seconds: 2));
      // Actual PDF processing logic here
    } finally {
      setProcessing(false);
    }
  }
}