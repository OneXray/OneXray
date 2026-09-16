import 'dart:convert';
import 'dart:typed_data';

import 'package:onexray/core/backup/model.dart';

const backupFileName = 'OneXray-backup.json';
const backupByteLimit = 64 * 1024 * 1024;

BackupDocument decodeBackup(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > backupByteLimit) {
    throw const FormatException('Backup must be between 1 byte and 64 MiB');
  }
  // Do not include malformed JSON, private keys or Base64 source in diagnostics.
  try {
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic> ||
        json['format'] != 'onexray-backup' ||
        json['version'] != 1 ||
        json['createdAt'] is! int ||
        (json['createdAt'] as int) <= 0) {
      throw const FormatException('Unsupported backup format');
    }
    final document = BackupDocument.fromJson(json);
    DateTime.fromMillisecondsSinceEpoch(document.createdAt);
    return document;
  } catch (_) {
    throw const FormatException('Invalid or unsupported OneXray backup');
  }
}

Uint8List encodeBackup(BackupDocument document) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(document.toJson())));
  decodeBackup(bytes);
  return bytes;
}

Map<String, dynamic> decodeBackupConfiguration(String data) {
  try {
    final json = jsonDecode(utf8.decode(base64Decode(data)));
    if (json is Map<String, dynamic>) return json;
  } catch (_) {
    // The caller reports the configuration's name, never its credentials.
  }
  throw const FormatException('Invalid Base64 JSON configuration in backup');
}
