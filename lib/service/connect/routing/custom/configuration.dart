import 'package:onexray/core/errors/failure.dart';

/// Shared identity and node selection, not a shared editable field model.
/// Ordinary forms and advanced JSON retain separate representations.
abstract interface class RoutingConfiguration {
  int? get id;
  String get name;
  int get entryCount;
  int get ruleCount;
  bool get advanced;
  Map<String, dynamic> toJson();
  String encode();
  void validate();
  RoutingConfiguration copyWith({int? id, bool clearId = false, String? name});
}

class CustomRoutingEditorException extends AppFailure {
  final String reason;
  const CustomRoutingEditorException(this.reason)
    : super(
        reason == 'changed' || reason == 'missing'
            ? FailureCategory.conflict
            : FailureCategory.input,
        reason,
      );
}
