import 'package:onexray/core/pigeon/messages.g.dart';

class InstalledAppParams {
  final List<AndroidAppInfo> allApps;
  final Set<String> selections;

  InstalledAppParams(this.allApps, this.selections);
}
