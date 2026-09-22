import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/tools/json_document.dart';

void main() {
  test('positions count UTF-16 units and CRLF as one line break', () {
    final document = JsonDocument('中😀\r\nab\n');
    expect(document.positionAt(3).line, 0);
    expect(document.positionAt(3).column, 3);
    expect(document.positionAt(5).line, 1);
    expect(document.positionAt(5).column, 0);
    expect(document.positionAt(8).line, 2);
    expect(document.positionAt(8).column, 0);
    expect(document.offsetAt(1, 2), 7);
    expect(document.offsetAt(0, 100), 3);
    expect(document.offsetAt(2, 0), 8);
    expect(document.positionAt(-1).column, 0);
    expect(document.positionAt(100).line, 2);
  });

  test('indexes escaped keys and array values against the original source', () {
    final text = r'{"a\"b": ["中文😀", 7], "escaped\u006bey": true}';
    final document = JsonDocument(text);
    final emoji = document.rangeForPath(['a"b', 0])!;
    expect(text.substring(emoji.start, emoji.end), '"中文😀"');
    final number = document.rangeForPath(['a"b', 1])!;
    expect(text.substring(number.start, number.end), '7');
    final escaped = document.rangeForPath(['escapedkey'])!;
    expect(text.substring(escaped.start, escaped.end), 'true');
    expect(document.rangeForPath(['a"b', 2]), isNull);
    expect(document.rangeForPath(['a"b', '0']), isNull);
  });

  test(
    'duplicate decoded keys and their descendants never select arbitrarily',
    () {
      final document = JsonDocument(
        r'{"a":{"x":1}, "\u0061":{"x":2}, "safe":{"a":3}}',
      );
      expect(document.rangeForPath(['a']), isNull);
      expect(document.rangeForPath(['a', 'x']), isNull);
      expect(document.rangeForPath(['safe', 'a']), isNotNull);
      expect(
        document.rangeForDiagnostic(
          const JsonDiagnostic('duplicate', path: ['a']),
        ),
        isNull,
      );
      expect(
        document.rangeForDiagnostic(
          const JsonDiagnostic('missing', path: ['a', 'missing']),
        ),
        isNull,
      );
    },
  );

  test('missing field locates its unique object and explicit offset wins', () {
    const text = '{"outbounds":[{"settings":{}}]}';
    final document = JsonDocument(text);
    final missing = document.rangeForDiagnostic(
      const JsonDiagnostic('required', path: ['outbounds', 0, 'protocol']),
    )!;
    expect(text.substring(missing.start, missing.end), '{"settings":{}}');
    final explicit = document.rangeForDiagnostic(
      const JsonDiagnostic('syntax', offset: 1, length: 2, path: ['outbounds']),
    )!;
    expect(explicit.start, 1);
    expect(explicit.end, 3);
    final end = document.rangeForDiagnostic(
      const JsonDiagnostic('end', offset: text.length),
    )!;
    expect(end.start, text.length);
    expect(end.end, text.length);
  });

  test(
    'syntax diagnostics retain decoder offsets without imposing root types',
    () {
      for (final valid in [
        'null',
        '42',
        '[]',
        '"中文😀"',
        '{"futureField":{"x":true}}',
      ]) {
        expect(JsonDocument(valid).syntaxError, isNull);
      }
      const text = '{"中文😀": 1,\r\n "value": }';
      final error = JsonDocument(text).syntaxError!;
      expect(error.offset, text.indexOf('}'));
      final position = JsonDocument(text).positionAt(error.offset!);
      expect(position.line, 1);
      expect(position.column, 10);
      expect(JsonDocument('{"value":').syntaxError!.offset, 9);
      expect(JsonDocument('{"value":"unterminated').syntaxError, isNotNull);
    },
  );

  test('unfinished strings are safely indexed for advisory lookup', () {
    const text = '{"routing":{"rules":[{"outboundTag":"dir';
    final document = JsonDocument(text);
    final range = document.rangeForPath([
      'routing',
      'rules',
      0,
      'outboundTag',
    ])!;
    expect(text.substring(range.start, range.end), '"dir');
  });

  test('exceeding index depth disables every path without rejecting JSON', () {
    final nested =
        '${List.filled(260, '[').join()}{"target":1}${List.filled(260, ']').join()}';
    final document = JsonDocument('{"before":0,"deep":$nested,"after":2}');
    expect(document.syntaxError, isNull);
    expect(document.rangeForPath([]), isNull);
    expect(document.rangeForPath(['before']), isNull);
    expect(document.rangeForPath(['deep']), isNull);
    expect(document.rangeForPath(['after']), isNull);
    expect(
      document.rangeForDiagnostic(
        const JsonDiagnostic('missing', path: ['missing']),
      ),
      isNull,
    );
    expect(
      document
          .rangeForDiagnostic(const JsonDiagnostic('offset', offset: 1))!
          .start,
      1,
    );
  });

  test(
    'structured diagnostics survive failure wrapping without parsing prose',
    () {
      const structured = JsonDiagnostic(
        'field missing',
        path: ['routing', 'rules'],
      );
      const failure = AppFailure(
        FailureCategory.configuration,
        'save',
        cause: AppFailure(FailureCategory.input, 'parse', cause: structured),
      );
      expect(JsonDiagnostic.fromError(failure), same(structured));
      expect(structured, isA<FormatException>());
      expect(structured.toString(), 'field missing');
      final format = JsonDiagnostic.fromError(
        const FormatException('syntax', null, 7),
      )!;
      expect(format.offset, 7);
      expect(format.toString(), 'syntax');
      final core = JsonDiagnostic.fromError(
        const FormatException('routing.rules[0] failed at offset 42'),
      )!;
      expect(core.path, isNull);
      expect(core.offset, isNull);
      expect(JsonDocument('{}').rangeForDiagnostic(core), isNull);
      expect(JsonDiagnostic.fromError(StateError('failure at line 2')), isNull);
    },
  );
}
