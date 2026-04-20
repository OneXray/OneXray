import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/ads/service.dart';

class GoogleAdsRowState {
  final NativeAd? nativeAd;
  final bool nativeAdIsLoaded;

  const GoogleAdsRowState({this.nativeAd, this.nativeAdIsLoaded = false});

  GoogleAdsRowState copyWith({NativeAd? nativeAd, bool? nativeAdIsLoaded}) {
    return GoogleAdsRowState(
      nativeAd: nativeAd ?? this.nativeAd,
      nativeAdIsLoaded: nativeAdIsLoaded ?? this.nativeAdIsLoaded,
    );
  }
}

class GoogleAdsRowController extends Cubit<GoogleAdsRowState> {
  GoogleAdsRowController() : super(const GoogleAdsRowState()) {
    _loadAd();
  }

  final _adUnitId = AdsService.adUnitId;

  Future<void> _loadAd() async {
    final canRequestAds = await AdsService().canRequestAds;
    if (!canRequestAds) {
      ygLogger(
        'Ad request is not allowed. Check user consent and ad settings.',
      );
      return;
    }
    final ad = NativeAd(
      adUnitId: _adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) => _onAdLoaded(ad),
        onAdFailedToLoad: (ad, error) => _onAdFailedToLoad(ad, error),
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    )..load();
    emit(state.copyWith(nativeAd: ad));
  }

  void _onAdLoaded(Ad ad) {
    ygLogger('NativeAd loaded.');
    emit(state.copyWith(nativeAdIsLoaded: true));
  }

  void _onAdFailedToLoad(Ad ad, LoadAdError error) {
    ygLogger('NativeAd failed to load: $error');
    ad.dispose();
    emit(state.copyWith(nativeAdIsLoaded: false));
  }

  @override
  Future<void> close() {
    state.nativeAd?.dispose();
    return super.close();
  }
}
