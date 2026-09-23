import 'dart:convert';

/// Lexical hints for source indexing and completion, never JSON validation.
enum JsonTokenKind {
  objectStart,
  objectEnd,
  arrayStart,
  arrayEnd,
  colon,
  comma,
  string,
  literal,
}

class JsonToken {
  final JsonTokenKind kind;
  final int start;
  final int end;
  final String? value;
  final bool closed;

  const JsonToken(
    this.kind,
    this.start,
    this.end, {
    this.value,
    this.closed = true,
  });

  int get contentEnd => kind == JsonTokenKind.string && closed ? end - 1 : end;
}

List<JsonToken> scanJsonTokens(String text) {
  final tokens = <JsonToken>[];
  var offset = 0;
  while (offset < text.length) {
    final unit = text.codeUnitAt(offset);
    if (unit == 32 || unit == 9 || unit == 10 || unit == 13) {
      offset++;
      continue;
    }
    final start = offset++;
    final punctuation = switch (unit) {
      123 => JsonTokenKind.objectStart,
      125 => JsonTokenKind.objectEnd,
      91 => JsonTokenKind.arrayStart,
      93 => JsonTokenKind.arrayEnd,
      58 => JsonTokenKind.colon,
      44 => JsonTokenKind.comma,
      _ => null,
    };
    if (punctuation != null) {
      tokens.add(JsonToken(punctuation, start, offset));
      continue;
    }
    if (unit == 34) {
      var closed = false;
      while (offset < text.length) {
        final next = text.codeUnitAt(offset);
        if (next == 10 || next == 13) break;
        offset++;
        if (next == 34) {
          closed = true;
          break;
        }
        if (next == 92 && offset < text.length) {
          if (text.codeUnitAt(offset) == 10 || text.codeUnitAt(offset) == 13) {
            break;
          }
          offset++;
        }
      }
      String? value;
      try {
        value = jsonDecode(
          '${text.substring(start, offset)}${closed ? '' : '"'}',
        ) as String;
      } on FormatException {
        // An incomplete escape is not enough context for a safe replacement.
      }
      tokens.add(
        JsonToken(
          JsonTokenKind.string,
          start,
          offset,
          value: value,
          closed: closed,
        ),
      );
      continue;
    }
    while (offset < text.length && !' \t\r\n{}[]:,"'.contains(text[offset])) {
      offset++;
    }
    tokens.add(JsonToken(JsonTokenKind.literal, start, offset));
  }
  return tokens;
}
