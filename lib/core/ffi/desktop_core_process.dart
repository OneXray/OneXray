import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'desktop_core_process.g.dart';

@JsonSerializable(includeIfNull: false)
class DesktopCoreProcessRecord {
  final int pid;

  const DesktopCoreProcessRecord({required this.pid});

  factory DesktopCoreProcessRecord.fromJson(Map<String, dynamic> json) =>
      _$DesktopCoreProcessRecordFromJson(json);

  Map<String, dynamic> toJson() => _$DesktopCoreProcessRecordToJson(this);
}

class DesktopCoreProcessStore {
  static const _fileName = 'core-process.json';

  Future<DesktopCoreProcessRecord?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return null;
      }
      final value = JsonTool.decoder.convert(await file.readAsString());
      return DesktopCoreProcessRecord.fromJson(value as Map<String, dynamic>);
    } catch (error) {
      ygLogger('read desktop core process record failed: $error');
      await clear();
      return null;
    }
  }

  Future<void> write(DesktopCoreProcessRecord record) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      JsonTool.encoder.convert(record.toJson()),
      flush: true,
    );
  }

  Future<void> clear({int? pid}) async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return;
      }
      if (pid != null) {
        final record = await read();
        if (record != null && record.pid != pid) {
          return;
        }
      }
      await file.delete();
    } catch (error) {
      ygLogger('clear desktop core process record failed: $error');
    }
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'run', _fileName));
  }
}
