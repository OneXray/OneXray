import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/servers/subscription/user_info.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22);
  SubscriptionUserInfo? parse(String? header) =>
      SubscriptionUserInfo.parse(header, updatedAt: now);

  test('reads byte counts, Unix expiry, case, whitespace and extra fields', () {
    final info = parse(
      ' Upload = 100; download=200; total=1000; expire=1790812800; extra=abc;',
    )!;
    expect(info.uploadBytes, 100);
    expect(info.downloadBytes, 200);
    expect(info.totalBytes, 1000);
    expect(info.usedBytes, 300);
    expect(info.remainingBytes, 700);
    expect(info.unlimited, isFalse);
    expect(info.exhausted, isFalse);
    expect(info.updatedAt, now);
    expect(info.expiresAt, DateTime.utc(2026, 10));
    expect(info.isExpired(now), isFalse);
    expect(info.isExpired(info.expiresAt!), isTrue);
  });

  test('explicit zero limits are different from missing limits', () {
    final unlimited = parse('upload=0; download=100; total=0; expire=0')!;
    expect(unlimited.unlimited, isTrue);
    expect(unlimited.remainingBytes, isNull);
    expect(unlimited.exhausted, isFalse);
    expect(unlimited.expireTimestamp, 0);
    expect(unlimited.expiresAt, isNull);
    expect(unlimited.isExpired(now), isFalse);
    final unknown = parse('upload=0; download=100')!;
    expect(unknown.usedBytes, 100);
    expect(unknown.totalBytes, isNull);
    expect(unknown.unlimited, isFalse);
    expect(unknown.remainingBytes, isNull);
    expect(unknown.expireTimestamp, isNull);
  });

  test('partial usage never treats a missing direction as zero', () {
    for (final header in ['upload=12; total=100', 'download=12; total=100']) {
      final info = parse(header)!;
      expect(info.usedBytes, isNull);
      expect(info.remainingBytes, isNull);
      expect(info.exhausted, isFalse);
    }
  });

  test('used counters remain intact when the finite quota is exhausted', () {
    for (final download in [90, 120]) {
      final info = parse('upload=10; download=$download; total=100')!;
      expect(info.remainingBytes, 0);
      expect(info.exhausted, isTrue);
      expect(info.usedBytes, 10 + download);
    }
  });

  test('malformed fields are independent and unknown data is not guessed', () {
    for (final value in [
      '-1',
      '1.5',
      '1e3',
      '0x10',
      'NaN',
      'infinity',
      '',
      '9223372036854775808',
    ]) {
      final info = parse('total=$value; expire=$value; upload=12')!;
      expect(info.totalBytes, isNull, reason: value);
      expect(info.expireTimestamp, isNull, reason: value);
      expect(info.uploadBytes, 12);
    }
    expect(parse('expire=253402300800'), isNull);
    expect(parse('expire=253402300799')!.expiresAt!.year, 9999);
    for (final header in [null, '', 'plan=unlimited', 'total=bad;expire=-1']) {
      expect(parse(header), isNull);
    }
  });

  test(
    'duplicate fields are ambiguous; combined headers retain other fields',
    () {
      final info = parse('total=500, total=0; total=1000; download=24')!;
      expect(info.totalBytes, isNull);
      expect(info.downloadBytes, 24);
      expect(info.unlimited, isFalse);
    },
  );

  test('large counters cannot wrap the used or remaining counts', () {
    final info = parse(
      'upload=9223372036854775807; download=1; total=9223372036854775807',
    )!;
    expect(info.uploadBytes, 0x7fffffffffffffff);
    expect(info.usedBytes, isNull);
    expect(info.remainingBytes, isNull);
  });
}
