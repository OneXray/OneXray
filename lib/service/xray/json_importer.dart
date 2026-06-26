import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/tools/json.dart';

enum JsonImportStatus { success, canceled, invalid }

final class JsonImportResult {
  final JsonImportStatus status;
  final String? text;

  const JsonImportResult._(this.status, this.text);

  const JsonImportResult.success(String text)
    : this._(JsonImportStatus.success, text);

  const JsonImportResult.canceled() : this._(JsonImportStatus.canceled, null);

  const JsonImportResult.invalid() : this._(JsonImportStatus.invalid, null);

  bool get isCanceled => status == JsonImportStatus.canceled;
}

final class JsonImporter {
  static Future<JsonImportResult> pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["txt", "json"],
      );
      if (result == null) {
        return const JsonImportResult.canceled();
      }

      final path = result.files.single.path;
      if (path == null) {
        return const JsonImportResult.invalid();
      }

      final text = await File(path).readAsString();
      return format(text);
    } catch (_) {
      return const JsonImportResult.invalid();
    }
  }

  static Future<JsonImportResult> readPasteboard() async {
    try {
      final hasStrings = await Clipboard.hasStrings();
      if (!hasStrings) {
        return const JsonImportResult.invalid();
      }

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null) {
        return const JsonImportResult.invalid();
      }

      return format(text);
    } catch (_) {
      return const JsonImportResult.invalid();
    }
  }

  static JsonImportResult format(String text) {
    final rawText = text.trim();
    try {
      final decoded = JsonTool.decoder.convert(rawText);
      return JsonImportResult.success(JsonTool.encoderForFile.convert(decoded));
    } catch (_) {
      return const JsonImportResult.invalid();
    }
  }
}
