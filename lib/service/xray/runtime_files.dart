import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/service/connection/runtime.dart';

abstract final class RuntimeDiagnosticFiles {
  static const logChunkBytes = 1024 * 1024;
  static const logExportBytes = 64 * 1024 * 1024;

  static String? logPath(ConnectionRuntime? runtime, {required bool access}) {
    if (runtime == null) return null;
    final log = (jsonDecode(runtime.xrayJson) as Map<String, dynamic>)['log'];
    final path = log is Map ? log[access ? 'access' : 'error'] : null;
    return path is String && path.isNotEmpty && path != 'none' ? path : null;
  }

  static Future<String> readConfiguration({String? text, String? path}) async {
    const limit = 16 * 1024 * 1024;
    if (text != null) {
      if (utf8.encode(text).length > limit) {
        throw const FormatException('Configuration is too large');
      }
      return text;
    }
    if (path == null || path.isEmpty) {
      throw const FileSystemException('Configuration is unavailable');
    }
    final file = File(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() > limit) {
      throw const FileSystemException('Configuration is unavailable');
    }
    return file.readAsString();
  }

  static Future<bool> exportConfiguration(String text) => FileTool.saveData(
    Uint8List.fromList(utf8.encode(text)),
    'OneXray-runtime.json',
    'json',
  );

  /// The System Extension owns its fixed log files; other hosts use the path.
  static Future<NativeLogChunk?> readLog(
    String path, {
    bool systemExtension = false,
    bool access = true,
    int offset = -1,
    int limit = logChunkBytes,
  }) async {
    if (offset < -1 || limit <= 0 || limit > logChunkBytes) {
      throw const FormatException('Invalid log request');
    }
    if (systemExtension) {
      return AppHostApi().readLog(access: access, offset: offset, limit: limit);
    }
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const FileSystemException('Log file is unavailable');
    }
    final file = await File(path).open();
    try {
      final size = await file.length();
      final start = offset == -1 ? max(0, size - limit) : min(offset, size);
      await file.setPosition(start);
      final data = await file.read(min(size - start, limit));
      return NativeLogChunk(
        data: data,
        offset: start,
        size: size,
        fileId: path,
      );
    } finally {
      await file.close();
    }
  }

  static Future<Uint8List> readLogForExport(
    String path, {
    bool systemExtension = false,
    bool access = true,
  }) async {
    if (systemExtension) {
      final first = await readLog(
        path,
        systemExtension: true,
        access: access,
        offset: 0,
      );
      if (first == null || first.size > logExportBytes || first.offset != 0) {
        throw const FileSystemException('Log file is unavailable');
      }
      final output = BytesBuilder(copy: false)..add(first.data);
      while (output.length < first.size) {
        final chunk = await readLog(
          path,
          systemExtension: true,
          access: access,
          offset: output.length,
          limit: min(first.size - output.length, logChunkBytes),
        );
        if (chunk == null ||
            chunk.fileId != first.fileId ||
            chunk.size < first.size ||
            chunk.offset != output.length ||
            chunk.data.isEmpty) {
          throw const FileSystemException('Log changed during export');
        }
        output.add(chunk.data);
      }
      return output.takeBytes();
    }
    final file = File(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FileSystemException('Log file is unavailable');
    }
    final handle = await file.open();
    try {
      final length = await handle.length();
      if (length > logExportBytes) {
        throw const FileSystemException('Log file is too large');
      }
      final bytes = await handle.read(length);
      if (bytes.length != length) {
        throw const FileSystemException('Log changed during export');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  static Future<bool> exportLog(
    String path,
    String name, {
    bool systemExtension = false,
    bool access = true,
  }) async => FileTool.saveData(
    await readLogForExport(
      path,
      systemExtension: systemExtension,
      access: access,
    ),
    name,
    'log',
  );
}
