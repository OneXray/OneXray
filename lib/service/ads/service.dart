import 'package:flutter/foundation.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onexray/core/tools/logger.dart';

/// https://github.com/googleads/googleads-mobile-flutter/blob/main/samples/admob/app_open_example/lib/main.dart
class AdsService {
  static final AdsService _singleton = AdsService._internal();

  factory AdsService() => _singleton;

  AdsService._internal();
  //======================

  // Google-provided test ad unit IDs. Public and documented — safe to commit
  // and ship in non-release builds.
  //   https://developers.google.com/admob/android/test-ads
  //   https://developers.google.com/admob/ios/test-ads
  static const _testAdUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const _testAdUnitIdIos = 'ca-app-pub-3940256099942544/3986624511';

  // Production ad unit IDs are injected at build time via --dart-define so the
  // real IDs never land in source control. When absent (e.g. fork builds with
  // no AdMob setup), we fall back to the test IDs — the app still runs and
  // loads Google test ads, but no real revenue flows.
  //
  //   flutter build <platform> --release \
  //     --dart-define=ADMOB_AD_UNIT_ID_ANDROID=ca-app-pub-XXX/YYY \
  //     --dart-define=ADMOB_AD_UNIT_ID_IOS=ca-app-pub-XXX/ZZZ
  static const _prodAdUnitIdAndroid =
      String.fromEnvironment('ADMOB_AD_UNIT_ID_ANDROID');
  static const _prodAdUnitIdIos =
      String.fromEnvironment('ADMOB_AD_UNIT_ID_IOS');

  static String get adUnitId {
    if (kReleaseMode) {
      if (AppPlatform.isAndroid) {
        return _prodAdUnitIdAndroid.isNotEmpty
            ? _prodAdUnitIdAndroid
            : _testAdUnitIdAndroid;
      } else if (AppPlatform.isIOS) {
        return _prodAdUnitIdIos.isNotEmpty
            ? _prodAdUnitIdIos
            : _testAdUnitIdIos;
      }
    } else {
      if (AppPlatform.isAndroid) {
        return _testAdUnitIdAndroid;
      } else if (AppPlatform.isIOS) {
        return _testAdUnitIdIos;
      }
    }
    return '';
  }

  Future<void> init() async {
    if (AppPlatform.isMobile) {
      await _initAds();
    }
  }

  void dispose() {}

  Future<void> _initAds() async {
    ConsentRequestParameters params;
    if (kReleaseMode) {
      params = ConsentRequestParameters();
    } else {
      final debugSettings = ConsentDebugSettings(
        // debugGeography: DebugGeography.debugGeographyRegulatedUsState,
      );
      params = ConsentRequestParameters(consentDebugSettings: debugSettings);
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () => _requestConsentInfoFinished(),
      (_) => _requestConsentInfoFinished(),
    );
  }

  void _requestConsentInfoFinished() {
    ygLogger("Consent info updated");
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      ygLogger("Consent form loaded and shown if required $error");
      _initSdkIfAllowed();
    });
  }

  Future<void> _initSdkIfAllowed() async {
    final canRequestAds = await this.canRequestAds;
    if (canRequestAds) {
      ygLogger("Initializing Mobile Ads SDK");
      MobileAds.instance.initialize();
    }
  }

  Future<bool> get canRequestAds async {
    return await ConsentInformation.instance.canRequestAds();
  }
}
