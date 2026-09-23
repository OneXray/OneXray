import 'dart:convert';

import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/tools/json_tokens.dart';

class JsonSourceRange {
  final int start;
  final int end;
  const JsonSourceRange(this.start, this.end);
}

class JsonSourcePosition {
  final int line;
  final int column;
  const JsonSourcePosition(this.line, this.column);
}

/// The source text owns offsets; decoded Maps cannot retain duplicate keys.
class JsonDocument {
  final String text;
  late final List<int> _lineStarts = _findLineStarts();
  late final _SourceNode? _root = _SourceParser(text).parse();
  late final JsonDiagnostic? syntaxError = _syntaxError();

  JsonDocument(this.text);

  JsonDiagnostic? _syntaxError() {
    try {
      jsonDecode(text);
      return null;
    } on FormatException catch (error) {
      return JsonDiagnostic(error.message, offset: error.offset);
    }
  }

  List<int> _findLineStarts() {
    final starts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 13) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 10) i++;
        starts.add(i + 1);
      } else if (text.codeUnitAt(i) == 10) {
        starts.add(i + 1);
      }
    }
    return starts;
  }

  JsonSourcePosition positionAt(int offset) {
    final bounded = offset.clamp(0, text.length);
    var low = 0;
    var high = _lineStarts.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (_lineStarts[middle] <= bounded) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return JsonSourcePosition(low, bounded - _lineStarts[low]);
  }

  int offsetAt(int line, int column) {
    final index = line.clamp(0, _lineStarts.length - 1);
    final start = _lineStarts[index];
    var end = index + 1 < _lineStarts.length
        ? _lineStarts[index + 1]
        : text.length;
    while (end > start &&
        (text.codeUnitAt(end - 1) == 10 || text.codeUnitAt(end - 1) == 13)) {
      end--;
    }
    return start + column.clamp(0, end - start);
  }

  JsonSourceRange? rangeForPath(List<Object> path) => _nodeForPath(path)?.range;

  JsonSourceRange? rangeForDiagnostic(JsonDiagnostic diagnostic) {
    final offset = diagnostic.offset;
    if (offset != null && offset >= 0 && offset <= text.length) {
      return JsonSourceRange(
        offset,
        (offset + diagnostic.length.clamp(0, text.length)).clamp(
          offset,
          text.length,
        ),
      );
    }
    final path = diagnostic.path;
    if (path == null) return null;
    final exact = _nodeForPath(path);
    if (exact != null) return exact.range;
    if (path.isEmpty || path.last is! String) return null;
    final parent = _nodeForPath(path.sublist(0, path.length - 1));
    // Only a missing property has an unambiguous parent. A duplicate does not.
    if (parent?.kind == JsonTokenKind.objectStart &&
        !parent!.properties.containsKey(path.last)) {
      return parent.range;
    }
    return null;
  }

  _SourceNode? _nodeForPath(List<Object> path) {
    var node = _root;
    for (final part in path) {
      if (node == null) return null;
      if (part is String && node.kind == JsonTokenKind.objectStart) {
        final children = node.properties[part];
        if (children == null || children.length != 1) return null;
        node = children.single;
      } else if (part is int && node.kind == JsonTokenKind.arrayStart) {
        if (part < 0 || part >= node.elements.length) return null;
        node = node.elements[part];
      } else {
        return null;
      }
    }
    return node;
  }
}

class _SourceNode {
  final JsonTokenKind kind;
  final int start;
  int end;
  final properties = <String, List<_SourceNode>>{};
  final elements = <_SourceNode>[];
  _SourceNode(JsonToken token)
    : kind = token.kind,
      start = token.start,
      end = token.end;
  JsonSourceRange get range => JsonSourceRange(start, end);
}

class _SourceParser {
  final String text;
  final List<JsonToken> tokens;
  var index = 0;
  var _tooDeep = false;
  _SourceParser(this.text) : tokens = scanJsonTokens(text);

  _SourceNode? parse() {
    final root = _parse(0);
    return _tooDeep ? null : root;
  }

  _SourceNode? _parse(int depth) {
    if (index >= tokens.length) return null;
    if (depth > 256) {
      _tooDeep = true;
      index = tokens.length;
      return null;
    }
    final token = tokens[index++];
    final node = _SourceNode(token);
    if (token.kind == JsonTokenKind.objectStart) {
      while (index < tokens.length) {
        final key = tokens[index++];
        if (key.kind == JsonTokenKind.objectEnd) {
          node.end = key.end;
          return node;
        }
        if (key.kind == JsonTokenKind.comma) continue;
        if (key.kind != JsonTokenKind.string || key.value == null) break;
        if (index >= tokens.length ||
            tokens[index].kind != JsonTokenKind.colon) {
          break;
        }
        index++;
        final value = _parse(depth + 1);
        if (value == null) break;
        node.properties.putIfAbsent(key.value!, () => []).add(value);
        node.end = value.end;
      }
      node.end = text.length;
    } else if (token.kind == JsonTokenKind.arrayStart) {
      while (index < tokens.length) {
        if (tokens[index].kind == JsonTokenKind.arrayEnd) {
          node.end = tokens[index++].end;
          return node;
        }
        if (tokens[index].kind == JsonTokenKind.comma) {
          index++;
          continue;
        }
        final value = _parse(depth + 1);
        if (value == null) break;
        node.elements.add(value);
        node.end = value.end;
      }
      node.end = text.length;
    } else if (token.kind != JsonTokenKind.string &&
        token.kind != JsonTokenKind.literal) {
      return null;
    }
    return node;
  }
}
