import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/invoke_limits.dart';

void main() {
  test('accepts UTF-8 JSON at the invoke size limit', () {
    final value = 'a' * LibXrayInvokeLimits.maxJsonBytes;
    expect(
      () => LibXrayInvokeLimits.validate(value, 'request'),
      returnsNormally,
    );
  });

  test('rejects multi-byte UTF-8 JSON above the invoke size limit', () {
    final value = '中' * (LibXrayInvokeLimits.maxJsonBytes ~/ 3 + 1);
    expect(
      () => LibXrayInvokeLimits.validate(value, 'request'),
      throwsA(isA<FormatException>()),
    );
  });
}
