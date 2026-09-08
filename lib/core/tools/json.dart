import 'dart:convert';

class JsonTool {
  static Map<String, dynamic> copyMap(Map<String, dynamic> value) => {
    for (final entry in value.entries) entry.key: _copyValue(entry.value),
  };

  static dynamic _copyValue(dynamic value) => switch (value) {
    Map<String, dynamic> object => copyMap(object),
    List values => values.map(_copyValue).toList(),
    null || String() || num() || bool() => value,
    _ => throw const FormatException('Invalid JSON value'),
  };

  static const encoder = JsonEncoder.withIndent("  ");

  static const decoder = JsonDecoder();

  static String encodeJsonToBase64(Map<String, dynamic> request) {
    final jsonStr = encoder.convert(request);
    final data = utf8.encode(jsonStr);
    final base64Text = base64Encode(data);
    return base64Text;
  }

  static dynamic decodeBase64ToJson(String base64Text) {
    final decoded = base64Decode(base64Text);
    final text = utf8.decode(decoded);
    final data = decoder.convert(text);
    return data;
  }
}
