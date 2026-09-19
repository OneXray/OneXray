import 'package:home_widget/home_widget.dart';

class TrafficWidgetService {
  static const provider = 'net.yuandev.onexray.widget.TrafficWidgetProvider';

  Future<bool> requestPin() async {
    if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: provider);
    // The launcher owns confirmation. Completing this request is not proof that
    // the user added a widget; normal provider callbacks draw the initial state.
    return true;
  }
}
