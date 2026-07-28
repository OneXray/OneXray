import 'dart:io';

import 'package:onexray/core/desktop_startup/adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:path/path.dart' as path;

final class LinuxLaunchAtLoginAdapter extends LaunchAtLoginAdapter {
  static const _desktopFileName = 'net.yuandev.onexray.desktop';

  final Map<String, String> _environment;
  final String _executable;

  LinuxLaunchAtLoginAdapter({
    Map<String, String>? environment,
    String? executable,
  }) : _environment = environment ?? Platform.environment,
       _executable = executable ?? Platform.resolvedExecutable;

  @override
  Future<LaunchAtLoginStatus> query() async {
    try {
      final file = _desktopFile();
      if (file == null) {
        return const LaunchAtLoginStatus.unavailable(
          message: 'Unable to resolve the XDG autostart directory.',
        );
      }
      if (!await file.exists()) {
        return const LaunchAtLoginStatus.disabled();
      }

      final values = _parseDesktopEntry(await file.readAsString());
      if (values['Hidden']?.toLowerCase() == 'true') {
        return const LaunchAtLoginStatus.disabled();
      }
      if (values['Type'] != 'Application' ||
          values['Exec'] != _execValue ||
          values['TryExec'] != _tryExecValue ||
          !await File(_executable).exists()) {
        return const LaunchAtLoginStatus.disabled(
          message: 'The existing autostart entry is stale.',
        );
      }
      return const LaunchAtLoginStatus.enabled();
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  @override
  Future<LaunchAtLoginStatus> setEnabled(bool enabled) async {
    try {
      final file = _desktopFile();
      if (file == null) {
        return const LaunchAtLoginStatus.unavailable(
          message: 'Unable to resolve the XDG autostart directory.',
        );
      }
      if (!enabled) {
        if (await file.exists()) {
          await file.delete();
        }
        return const LaunchAtLoginStatus.disabled();
      }
      if (!await File(_executable).exists()) {
        return const LaunchAtLoginStatus.error(
          'The OneXray executable does not exist.',
        );
      }

      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      try {
        await temporary.writeAsString(_desktopEntry, flush: true);
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) {
          await temporary.delete();
        }
      }
      return query();
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  File? _desktopFile() {
    final xdgConfigHome = _environment['XDG_CONFIG_HOME']?.trim();
    final home = _environment['HOME']?.trim();
    final configHome = xdgConfigHome?.isNotEmpty == true
        ? xdgConfigHome!
        : home?.isNotEmpty == true
        ? path.join(home!, '.config')
        : null;
    if (configHome == null) {
      return null;
    }
    return File(path.join(configHome, 'autostart', _desktopFileName));
  }

  String get _execValue => _quoteExecArgument(_executable);

  String get _tryExecValue => _escapeDesktopValue(_executable);

  String get _desktopEntry =>
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=OneXray\n'
      'Exec=$_execValue\n'
      'TryExec=$_tryExecValue\n'
      'Terminal=false\n';

  static Map<String, String> _parseDesktopEntry(String text) {
    final result = <String, String>{};
    var inDesktopEntry = false;
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']')) {
        inDesktopEntry = line == '[Desktop Entry]';
        continue;
      }
      if (!inDesktopEntry) {
        continue;
      }
      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      result[line.substring(0, separator)] = line.substring(separator + 1);
    }
    return result;
  }

  static String _quoteExecArgument(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('`', r'\`')
        .replaceAll(r'$', r'\$')
        .replaceAll('%', '%%');
    return '"$escaped"';
  }

  static String _escapeDesktopValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
  }
}
