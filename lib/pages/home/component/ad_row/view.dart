import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onexray/pages/home/component/ad_row/controller.dart';
import 'package:onexray/pages/theme/color.dart';

class GoogleAdsRow extends StatelessWidget {
  const GoogleAdsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GoogleAdsRowController(),
      child: BlocBuilder<GoogleAdsRowController, GoogleAdsRowState>(
        builder: (context, state) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, GoogleAdsRowState state) {
    if (state.nativeAdIsLoaded && state.nativeAd != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 320, // minimum recommended width
          minHeight: 90, // minimum recommended height
          maxWidth: 400,
          maxHeight: 110,
        ),
        child: AdWidget(ad: state.nativeAd!),
      );
    } else {
      return Container(height: 90, color: ColorManager.surface(context));
    }
  }
}
