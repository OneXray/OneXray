import 'dart:io';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:path/path.dart' as p;

class GeoDataInput {
  final String fileName;
  final GeoDataType type;
  final String url;
  const GeoDataInput({
    required this.fileName,
    required this.type,
    required this.url,
  });

  /// New entries use one lowercase .dat suffix. Existing database basenames are
  /// never normalized: their historical '$name.dat' references remain intact.
  String get name =>
      canonicalFileName(fileName)
          .substring(0, canonicalFileName(fileName).length - 4);

  static String canonicalFileName(String input) {
    final value = input.trim();
    final file = value.toLowerCase().endsWith('.dat')
        ? '${value.substring(0, value.length - 4)}.dat'
        : '$value.dat';
    if (value.isEmpty ||
        file.length > 255 ||
        p.posix.basename(file) != file ||
        p.windows.basename(file) != file ||
        file.contains(RegExp(r'[\\/:*?"<>|\x00-\x1f\x7f]')) ||
        file.startsWith('.') ||
        file.substring(0, file.length - 4).endsWith('.') ||
        file.substring(0, file.length - 4).endsWith(' ') ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])\.',
          caseSensitive: false,
        ).hasMatch(file) ||
        {'geoip.dat', 'geosite.dat'}.contains(file.toLowerCase())) {
      throw const FormatException('Invalid custom Geodata filename');
    }
    return file;
  }

  static Uri httpsUri(String value) {
    final uri = Uri.tryParse(value);
    if (value.contains(RegExp(r'\s')) ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException('An HTTPS Geodata URL is required');
    }
    return uri;
  }
}

class PublishedGeoData {
  final GeoDataData row;
  final File data;
  final File indexFile;
  final XrayGeoList index;
  final int bytes;
  const PublishedGeoData({
    required this.row,
    required this.data,
    required this.indexFile,
    required this.index,
    required this.bytes,
  });

  String get fileName => '${row.name}.dat';
  String get sourceHost => Uri.tryParse(row.url)?.host ?? row.url;
  bool get builtIn => row.id == -1 || row.id == -2;
  String reference(String code) =>
      builtIn ? '${row.name}:$code' : 'ext:$fileName:$code';
}

/// Downloaded files remain staged until the surrounding save starts. The
/// caller publishes them before validation, commits metadata in its database
/// transaction, then either completes or rolls the publication back.
class GeoDataImportDraft {
  final Future<void> Function() _publish;
  final Future<void> Function() _commit;
  final Future<void> Function() _complete;
  final Future<void> Function() _rollback;
  final Future<void> Function() _dispose;
  final List<GeoDataInput> inputs;
  GeoDataImportDraft(
    this.inputs,
    this._commit,
    this._dispose, {
    Future<void> Function()? publish,
    Future<void> Function()? complete,
    Future<void> Function()? rollback,
  }) : _publish = publish ?? _noop,
       _complete = complete ?? _noop,
       _rollback = rollback ?? _noop;

  Future<void> publish() => _publish();
  Future<void> commit() => _commit();
  Future<void> complete() => _complete();
  Future<void> rollback() => _rollback();
  Future<void> dispose() => _dispose();

  static Future<void> _noop() async {}
}

class GeoDataRestoreDraft {
  final Future<void> Function() _commit;
  final Future<void> Function() _complete;
  final Future<void> Function() _dispose;
  GeoDataRestoreDraft(this._commit, this._complete, this._dispose);
  Future<void> commit() => _commit();
  Future<void> complete() => _complete();
  Future<void> dispose() => _dispose();
}
