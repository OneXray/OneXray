import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/geo_data/enum.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/system_state.dart';
import 'package:onexray/service/geo_data/validator.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_validator.dart';
import 'package:onexray/service/xray/raw/db.dart';
import 'package:onexray/service/xray/raw/validator.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_db.dart';
import 'package:onexray/service/xray/setting/state_reader.dart';
import 'package:onexray/service/xray/setting/state_validator.dart';
import 'package:tuple/tuple.dart';

enum DeepLinkPath {
  subAdd("/sub/add"),
  configAdd("/config/add"),
  datAdd("/dat/add");

  const DeepLinkPath(this.name);

  final String name;

  @override
  String toString() => name;

  static DeepLinkPath? fromString(String name) =>
      DeepLinkPath.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return DeepLinkPath.values.map((e) => e.name).toList();
  }
}

class AppShareService {
  static final AppShareService _singleton = AppShareService._internal();

  factory AppShareService() => _singleton;

  AppShareService._internal();

  static const _appPrefix = "onexray://onexray.com";

  static const _scheme = "onexray";
  static const _host = "onexray.com";

  static const _pathKeyUrl = "url";
  static const _pathKeyType = "type";
  static const _pathKeyData = "data";

  bool checkAppShare(String link) {
    return link.startsWith(_appPrefix);
  }

  Future<Tuple2<List<CoreConfigCompanion>, bool>> parseShareText(
    String text, {
    bool needDownload = true,
    bool skipSubscription = false,
  }) async {
    final links = _fixWindowsReturn(text);
    final urls = links.split("\n");
    final rows = <CoreConfigCompanion>[];
    var success = false;
    for (final url in urls) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final result = await _readAppShareUrl(
          url,
          needDownload,
          skipSubscription,
        );
        if (result.item1 != null) {
          rows.add(result.item1!);
          success = true;
        } else {
          success = result.item2;
        }
      }
    }
    return Tuple2(rows, success);
  }

  Future<bool> addSubscription(
    String url,
    String name,
    bool showLoading,
  ) async {
    if (name.isEmpty) {
      name = "anonymous";
    }
    final checked = await SubscriptionValidator.validate(name, url);
    if (checked.item1) {
      final count = await SubscriptionService().insertSubscription(
        name,
        url,
        showLoading,
      );
      return count > 0;
    }
    return false;
  }

  Future<Tuple2<CoreConfigCompanion?, bool>> _readAppShareUrl(
    String url,
    bool needDownload,
    bool skipSubscription,
  ) async {
    var success = false;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return Tuple2(null, success);
    }
    final path = DeepLinkPath.fromString(uri.path);
    if (path == null) {
      return Tuple2(null, success);
    }
    switch (path) {
      case DeepLinkPath.subAdd:
        if (!skipSubscription) {
          success = await _readSubscription(uri);
        }
        return Tuple2(null, success);
      case DeepLinkPath.configAdd:
        final config = await _readConfig(uri);
        success = config != null;
        return Tuple2(config, success);
      case DeepLinkPath.datAdd:
        success = await _readGeoData(uri, needDownload);
        return Tuple2(null, success);
    }
  }

  Future<bool> _readSubscription(Uri uri) async {
    final queryParameters = uri.queryParameters;
    final url = queryParameters[_pathKeyUrl];
    if (url == null) {
      return false;
    }
    return addSubscription(url, uri.fragment, false);
  }

  Future<CoreConfigCompanion?> _readConfig(Uri uri) async {
    final queryParameters = uri.queryParameters;
    final type = queryParameters[_pathKeyType];
    if (type == null) {
      return null;
    }
    final typeEnum = CoreConfigType.fromString(type);
    if (typeEnum == null) {
      return null;
    }
    final data = queryParameters[_pathKeyData];
    if (data == null) {
      return null;
    }
    var name = uri.fragment;
    if (name.isEmpty) {
      name = "anonymous";
    }

    return _readXrayConfig(typeEnum, name, data);
  }

  Future<CoreConfigCompanion?> _readXrayConfig(
    CoreConfigType type,
    String name,
    String data,
  ) async {
    final text = _decodeConfigData(data);
    if (text == null) {
      return null;
    }

    switch (type) {
      case CoreConfigType.outbound:
        final state = OutboundState();
        final success = state.readFromText(text);
        if (success) {
          state.removeWhitespace();
          final check = await state.validate();
          if (check.item1) {
            return state.outboundCompanion;
          }
        }
        break;
      case CoreConfigType.setting:
        final state = XraySettingState();
        state.readFromText(text);
        state.removeWhitespace();
        final check = await state.validate();
        if (check.item1) {
          return state.configCompanion();
        }
        break;
      case CoreConfigType.raw:
        final check = await XrayRawValidator.validate(text);
        if (check.item1) {
          return XrayRawDb.configCompanion(name, text);
        }
        break;
    }
    return null;
  }

  Future<bool> _readGeoData(Uri uri, bool needDownload) async {
    final queryParameters = uri.queryParameters;
    final type = queryParameters[_pathKeyType];
    if (type == null) {
      return false;
    }
    final typeEnum = GeoDataType.fromString(type);
    if (typeEnum == null) {
      return false;
    }
    final url = queryParameters[_pathKeyUrl];
    if (url == null) {
      return false;
    }
    var name = uri.fragment;
    if (name.isEmpty) {
      name = "anonymous";
    }

    final checked = await GeoDataValidator.validate(name, url);
    if (checked.item1) {
      return GeoDataService().insertGeoDat(
        name,
        typeEnum,
        url,
        showLoading: false,
        needDownload: needDownload,
      );
    }
    return false;
  }

  String? _decodeConfigData(String data) {
    try {
      final bytes = base64Decode(data);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  String _fixWindowsReturn(String text) {
    if (text.contains("\r\n")) {
      return text.replaceAll("\r\n", "\n");
    }
    return text;
  }

  //==================================
  Future<Tuple2<String, String>> generateConfigLink(
    CoreConfigData config,
  ) async {
    if (config.data == null) {
      return Tuple2("", "");
    }
    final queryParameters = <String, String>{
      _pathKeyType: config.type,
      _pathKeyData: config.data!,
    };
    final url = Uri(
      scheme: _scheme,
      host: _host,
      path: DeepLinkPath.configAdd.name,
      queryParameters: queryParameters,
      fragment: config.name,
    );

    //generate geo files
    final geoFiles = await AppHostApi().readGeoFiles(config.data!);
    final geoLinks = await _generateGeoDataLinks(geoFiles);
    if (geoLinks.isEmpty) {
      return Tuple2(url.toString(), config.name);
    } else {
      geoLinks.add(url.toString());
      final link = geoLinks.join("\n");
      return Tuple2(link, config.name);
    }
  }

  Future<List<String>> _generateGeoDataLinks(
    ReadGeoFilesResponse geoFiles,
  ) async {
    final names = <String>[];
    names.addAll(_filterAndStripGeoFiles(geoFiles.domain));
    names.addAll(_filterAndStripGeoFiles(geoFiles.ip));

    final links = <String>[];
    final db = AppDatabase();
    for (final name in names) {
      final geoData = await db.geoDataDao.searchRowByName(name);
      if (geoData != null) {
        final res = generateGeoDataLink(geoData);
        links.add(res.item1);
      }
    }
    return links;
  }

  List<String> _filterAndStripGeoFiles(List<String>? geoFiles) {
    final files = <String>[];
    if (geoFiles == null) {
      return files;
    }
    if (geoFiles.isEmpty) {
      return files;
    }

    for (final file in geoFiles) {
      final name = file.replaceAll(".dat", "");
      if (name == SystemGeoDatName.geoSite.name) {
        continue;
      }
      if (name == SystemGeoDatName.geoIp.name) {
        continue;
      }
      files.add(name);
    }
    return files;
  }

  Tuple2<String, String> generateSubscriptionLink(
    SubscriptionData subscription,
  ) {
    final queryParameters = <String, String>{_pathKeyUrl: subscription.url};
    final url = Uri(
      scheme: _scheme,
      host: _host,
      path: DeepLinkPath.subAdd.name,
      queryParameters: queryParameters,
      fragment: subscription.name,
    );
    return Tuple2(url.toString(), subscription.name);
  }

  Tuple2<String, String> generateGeoDataLink(GeoDataData geoData) {
    final queryParameters = <String, String>{
      _pathKeyUrl: geoData.url,
      _pathKeyType: geoData.type,
    };
    final url = Uri(
      scheme: _scheme,
      host: _host,
      path: DeepLinkPath.datAdd.name,
      queryParameters: queryParameters,
      fragment: geoData.name,
    );
    return Tuple2(url.toString(), geoData.name);
  }
}
