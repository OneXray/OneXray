import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/pages/launch/init.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyState {
  final String md;

  const PrivacyState({this.md = ""});

  PrivacyState copyWith({String? md}) {
    return PrivacyState(md: md ?? this.md);
  }
}

class PrivacyController extends Cubit<PrivacyState> {
  PrivacyController() : super(const PrivacyState()) {
    _readPrivacy();
  }

  Future<void> _readPrivacy() async {
    final md = await rootBundle.loadString(Assets.md.privacy);
    emit(state.copyWith(md: md));
  }

  Future<void> openUrl(String? url) async {
    if (url == null) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri);
      } catch (e) {
        ygLogger("openUrl error: $e");
      }
    }
  }

  Future<void> accept(BuildContext context) async {
    await PreferencesKey().savePrivacyAccepted(true);
    if (context.mounted) {
      checkFirstRun(context);
    }
  }
}
