import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/core/xray/profile_list/controller.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

void main() {
  test('Simple Profile uses the Simple editor route', () {
    expect(
      XrayProfileListController.editorDestination(XrayProfileSimple.simpleId),
      AppSecondaryDestination.xrayProfileSimple,
    );
  });

  test('custom Profiles use the Custom editor route', () {
    expect(
      XrayProfileListController.editorDestination(42),
      AppSecondaryDestination.xrayProfileUI,
    );
  });
}
