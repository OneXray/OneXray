import 'dart:collection';
import 'dart:convert';

class JsonTool {
  static const encoder = JsonEncoder.withIndent("  ");

  static String encodeJsonToSortedString(Map<String, dynamic> jsonMap) {
    final sortedMap = SplayTreeMap.from(jsonMap);
    return encoder.convert(sortedMap);
  }

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
