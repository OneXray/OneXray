import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

final class BackupArchiveException implements Exception {
  final String message;

  const BackupArchiveException(this.message);

  @override
  String toString() => message;
}

final class BackupArchiveLimits {
  final int maxArchiveBytes;
  final int maxExtractedBytes;
  final int maxFileBytes;
  final int maxFileCount;

  const BackupArchiveLimits({
    this.maxArchiveBytes = 512 * 1024 * 1024,
    this.maxExtractedBytes = 1024 * 1024 * 1024,
    this.maxFileBytes = 512 * 1024 * 1024,
    this.maxFileCount = 4096,
  });
}

final class BackupArchiveExtractor {
  final Set<String> rootFiles;
  final String dataDirectory;
  final BackupArchiveLimits limits;

  const BackupArchiveExtractor({
    required this.rootFiles,
    required this.dataDirectory,
    this.limits = const BackupArchiveLimits(),
  });

  Future<void> extract(String archivePath, String outputPath) async {
    final source = File(archivePath);
    if (!await source.exists()) {
      throw const BackupArchiveException('backup archive does not exist');
    }
    if (await source.length() > limits.maxArchiveBytes) {
      throw const BackupArchiveException('backup archive is too large');
    }
    if (await _readZipEntryCount(source) > limits.maxFileCount) {
      throw const BackupArchiveException('backup contains too many files');
    }

    final input = InputFileStream(archivePath);
    Archive? archive;
    try {
      archive = ZipDecoder().decodeStream(input);
      final entries = _validate(archive);
      await Directory(
        p.join(outputPath, dataDirectory),
      ).create(recursive: true);
      for (final entry in entries) {
        final destination = p.joinAll([
          outputPath,
          ...p.posix.split(entry.path),
        ]);
        await Directory(p.dirname(destination)).create(recursive: true);
        final output = OutputFileStream(destination);
        try {
          entry.file.writeContent(output);
        } finally {
          await output.close();
        }
      }
    } finally {
      await input.close();
      if (archive != null) {
        await archive.clear();
      }
    }
  }

  Future<int> _readZipEntryCount(File source) async {
    const eocdSize = 22;
    const maxCommentSize = 0xffff;
    final length = await source.length();
    if (length < eocdSize) {
      throw const BackupArchiveException('backup archive is invalid');
    }
    final start = max(0, length - eocdSize - maxCommentSize);
    final input = await source.open();
    try {
      await input.setPosition(start);
      final bytes = Uint8List.fromList(await input.read(length - start));
      final data = ByteData.sublistView(bytes);
      for (var offset = bytes.length - eocdSize; offset >= 0; offset--) {
        if (data.getUint32(offset, Endian.little) != 0x06054b50) {
          continue;
        }
        final commentLength = data.getUint16(offset + 20, Endian.little);
        if (offset + eocdSize + commentLength != bytes.length) {
          continue;
        }
        final disk = data.getUint16(offset + 4, Endian.little);
        final centralDisk = data.getUint16(offset + 6, Endian.little);
        final entriesOnDisk = data.getUint16(offset + 8, Endian.little);
        final entries = data.getUint16(offset + 10, Endian.little);
        final centralSize = data.getUint32(offset + 12, Endian.little);
        final centralOffset = data.getUint32(offset + 16, Endian.little);
        if (disk != 0 ||
            centralDisk != 0 ||
            entriesOnDisk != entries ||
            entries == 0xffff ||
            centralSize == 0xffffffff ||
            centralOffset == 0xffffffff ||
            centralOffset + centralSize > length) {
          throw const BackupArchiveException(
            'backup archive layout is unsupported',
          );
        }
        return entries;
      }
    } finally {
      await input.close();
    }
    throw const BackupArchiveException('backup archive is invalid');
  }

  List<({ArchiveFile file, String path})> _validate(Archive archive) {
    var fileCount = 0;
    var extractedBytes = 0;
    final paths = <String>{};
    final entries = <({ArchiveFile file, String path})>[];

    for (final file in archive) {
      final path = _normalizePath(file.name);
      if (file.isDirectory) {
        if (path != dataDirectory) {
          throw const BackupArchiveException(
            'backup contains an unexpected directory',
          );
        }
        continue;
      }
      if (!file.isFile || file.isSymbolicLink || !_isAllowedFile(path)) {
        throw const BackupArchiveException(
          'backup contains an unexpected file',
        );
      }
      if (!paths.add(path)) {
        throw const BackupArchiveException('backup contains duplicate files');
      }

      fileCount++;
      if (fileCount > limits.maxFileCount) {
        throw const BackupArchiveException('backup contains too many files');
      }
      if (file.size < 0 || file.size > limits.maxFileBytes) {
        throw const BackupArchiveException('backup file is too large');
      }
      extractedBytes += file.size;
      if (extractedBytes > limits.maxExtractedBytes) {
        throw const BackupArchiveException('backup expands beyond the limit');
      }
      entries.add((file: file, path: path));
    }
    return entries;
  }

  String _normalizePath(String value) {
    final source = value.replaceAll('\\', '/');
    final normalized = p.posix.normalize(source);
    if (normalized.isEmpty ||
        normalized == '.' ||
        p.posix.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized != source.replaceAll(RegExp(r'/+$'), '')) {
      throw const BackupArchiveException('backup contains an invalid path');
    }
    return normalized;
  }

  bool _isAllowedFile(String path) {
    if (rootFiles.contains(path)) {
      return true;
    }
    final parts = p.posix.split(path);
    if (parts.length != 2 || parts.first != dataDirectory) {
      return false;
    }
    final extension = p.posix.extension(parts.last).toLowerCase();
    return extension == '.dat' || extension == '.json';
  }
}
