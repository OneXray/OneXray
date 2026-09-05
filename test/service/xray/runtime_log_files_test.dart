import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/xray/runtime_files.dart';

void main() {
  test('local logs keep bounded reads and full export', () async {
    final root = await Directory('../references/runtime-log-tests').absolute
        .create(recursive: true);
    final directory = await root.createTemp('files-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/access.log');
    await file.writeAsString('first\nsecond\n');
    final tail = await RuntimeDiagnosticFiles.readLog(file.path, limit: 7);
    expect(tail!.offset, 6);
    expect(tail.size, 13);
    expect(String.fromCharCodes(tail.data), 'second\n');
    expect(
      String.fromCharCodes(
        await RuntimeDiagnosticFiles.readLogForExport(file.path),
      ),
      'first\nsecond\n',
    );

    await file.writeAsString('third\n', mode: FileMode.append);
    final next = await RuntimeDiagnosticFiles.readLog(
      file.path,
      offset: tail.size,
    );
    expect(next!.offset, 13);
    expect(next.size, 19);
    expect(String.fromCharCodes(next.data), 'third\n');

    await file.writeAsString('new\n');
    final truncated = await RuntimeDiagnosticFiles.readLog(
      file.path,
      offset: next.size,
    );
    expect(truncated!.offset, 4);
    expect(truncated.size, 4);
    expect(truncated.data, isEmpty);

    expect(
      await RuntimeDiagnosticFiles.readLog('${directory.path}/missing.log'),
      isNull,
    );
    await Link('${directory.path}/link.log').create(file.path);
    for (final path in ['${directory.path}/link.log', directory.path]) {
      await expectLater(
        RuntimeDiagnosticFiles.readLog(path),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        RuntimeDiagnosticFiles.readLogForExport(path),
        throwsA(isA<FileSystemException>()),
      );
    }

    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(RuntimeDiagnosticFiles.logExportBytes + 1);
    await handle.close();
    await expectLater(
      RuntimeDiagnosticFiles.readLogForExport(file.path),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('invalid bounds are rejected before accessing a file', () async {
    for (final bounds in [
      (offset: -2, limit: 1),
      (offset: -1, limit: 0),
      (offset: 0, limit: RuntimeDiagnosticFiles.logChunkBytes + 1),
    ]) {
      await expectLater(
        RuntimeDiagnosticFiles.readLog(
          '/unused/access.log',
          offset: bounds.offset,
          limit: bounds.limit,
        ),
        throwsFormatException,
      );
    }
  });
}
