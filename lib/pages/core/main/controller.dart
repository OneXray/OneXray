import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:url_launcher/url_launcher.dart';

class CoreRootController extends Cubit<void> {
  CoreRootController() : super(null);

  Future<void> updateRunMode(CoreRunMode mode) async {
    await VpnService().switchRunMode(mode);
  }

  void gotoTun(BuildContext context) {
    context.goScoped(AppSecondaryDestination.tun);
  }

  void gotoPing(BuildContext context) {
    context.goScoped(AppSecondaryDestination.ping);
  }

  void gotoLogs(BuildContext context) {
    context.goScoped(AppSecondaryDestination.logs);
  }

  void gotoXray(BuildContext context) {
    context.goScoped(AppSecondaryDestination.xray);
  }

  void gotoGeoData(BuildContext context) {
    context.goScoped(
      AppSecondaryDestination.geoData,
      extra: GeoDataListParams(GeoDataListType.full, GeoDatCodesMode.show),
    );
  }

  final _routingTemplates = Uri.parse("https://github.com/OneXray/Routing");

  Future<void> openEnhancedRouting(BuildContext context) async {
    try {
      await launchUrl(_routingTemplates);
    } catch (e) {
      ygLogger("openEnhancedRouting error: $e");
    }
  }
}
