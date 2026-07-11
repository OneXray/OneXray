import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/model_reader.dart';

void main() {
  test('parses a valid libXray response', () {
    final response = LibXrayInvokeResponseParser.parse(
      '{"success":true,"data":{"running":true},"error":""}',
    );

    expect(response.success, isTrue);
    expect(response.data, {'running': true});
    expect(response.error, isEmpty);
  });

  for (final testCase in <({String name, String response})>[
    (name: 'malformed JSON', response: 'not-json'),
    (name: 'missing required fields', response: '{"data":null}'),
    (
      name: 'invalid field types',
      response: '{"success":"yes","data":[],"error":false}',
    ),
  ]) {
    test('returns failure for ${testCase.name}', () {
      final response = LibXrayInvokeResponseParser.parse(testCase.response);

      expect(response.success, isFalse);
      expect(response.data, isNull);
      expect(response.error, LibXrayInvokeResponseParser.invalidResponseError);
    });
  }
}
