import 'package:onexray/core/db/database/database.dart';

/// Provider-reported counters, never device or current-connection statistics.
class SubscriptionUserInfo {
  const SubscriptionUserInfo({
    this.uploadBytes,
    this.downloadBytes,
    this.totalBytes,
    this.expireTimestamp,
    required this.updatedAt,
  });

  final int? uploadBytes;
  final int? downloadBytes;
  final int? totalBytes;
  final int? expireTimestamp;
  final DateTime updatedAt;

  static const _maxBytes = 0x7fffffffffffffff;
  static const _maxExpire = 253402300799; // Last Unix second of year 9999.

  /// A malformed/ambiguous field is unknown, without discarding other fields
  /// or invalidating the subscription body. Header names are handled by Dio.
  static SubscriptionUserInfo? parse(
    String? header, {
    required DateTime updatedAt,
  }) {
    if (header == null) return null;
    final values = <String, int?>{};
    for (final part in header.split(RegExp('[;,]'))) {
      final separator = part.indexOf('=');
      if (separator < 0) continue;
      final key = part.substring(0, separator).trim().toLowerCase();
      if (!const {'upload', 'download', 'total', 'expire'}.contains(key)) {
        continue;
      }
      if (values.containsKey(key)) {
        values[key] = null;
        continue;
      }
      final raw = part.substring(separator + 1).trim();
      final value = RegExp(r'^[0-9]+$').hasMatch(raw)
          ? int.tryParse(raw)
          : null;
      final maximum = key == 'expire' ? _maxExpire : _maxBytes;
      values[key] = value != null && value >= 0 && value <= maximum
          ? value
          : null;
    }
    if (values.values.every((value) => value == null)) return null;
    return SubscriptionUserInfo(
      uploadBytes: values['upload'],
      downloadBytes: values['download'],
      totalBytes: values['total'],
      expireTimestamp: values['expire'],
      updatedAt: updatedAt,
    );
  }

  static SubscriptionUserInfo? fromSubscription(SubscriptionData row) {
    final updatedAt = row.userInfoUpdatedAt;
    if (updatedAt == null) return null;
    return SubscriptionUserInfo(
      uploadBytes: row.uploadBytes,
      downloadBytes: row.downloadBytes,
      totalBytes: row.totalBytes,
      expireTimestamp: row.expireTimestamp,
      updatedAt: updatedAt,
    );
  }

  int? get usedBytes {
    final upload = uploadBytes;
    final download = downloadBytes;
    if (upload == null || download == null || upload > _maxBytes - download) {
      return null;
    }
    return upload + download;
  }

  bool get unlimited => totalBytes == 0;

  int? get remainingBytes {
    final total = totalBytes;
    final used = usedBytes;
    if (total == null || total == 0 || used == null) return null;
    return used >= total ? 0 : total - used;
  }

  bool get exhausted => remainingBytes == 0;

  DateTime? get expiresAt {
    final expire = expireTimestamp;
    return expire == null || expire == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(expire * 1000, isUtc: true);
  }

  bool isExpired(DateTime now) => expiresAt?.isAfter(now) == false;
}
