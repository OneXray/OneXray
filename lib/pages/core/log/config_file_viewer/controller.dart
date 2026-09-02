import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/share.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:share_plus/share_plus.dart';

class ConfigFileViewerPageState {
  final String title;
  final String text;

  const ConfigFileViewerPageState({this.title = '', this.text = ''});

  ConfigFileViewerPageState copyWith({String? title, String? text}) {
    return ConfigFileViewerPageState(
      title: title ?? this.title,
      text: text ?? this.text,
    );
  }
}

class ConfigFileViewerController extends PageCubit<ConfigFileViewerPageState> {
  final ConfigFileViewerParams params;

  ConfigFileViewerController(this.params)
    : super(const ConfigFileViewerPageState()) {
    _initParams();
    _readFile();
  }

  void _initParams() {
    emit(state.copyWith(title: params.title));
  }

  Future<void> _readFile() async {
    final file = File(params.path);
    if (await file.exists()) {
      final text = await file.readAsString();
      emit(state.copyWith(text: text));
    }
  }

  Future<void> shareFile(BuildContext context) async {
    final sharePositionOrigin = ContextShare.positionOrigin(context);

    final file = File(params.path);
    if (await file.exists()) {
      final outcome = await ContextShare.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: [params.title],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      if (context.mounted && outcome != ShareOutcome.unconfirmed) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.actionResult(
            AppLocalizations.of(context)!.configFileViewerPageShare,
            outcome == ShareOutcome.success
                ? AppLocalizations.of(context)!.resultSuccess
                : AppLocalizations.of(context)!.resultFailed,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.configFileViewerPageFileNotExist,
        );
      }
    }
  }
}
