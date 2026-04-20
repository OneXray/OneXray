import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/setting/long_text/params.dart';
import 'package:share_plus/share_plus.dart';

class LongTextState {
  final String title;
  final String text;

  const LongTextState({this.title = '', this.text = ''});

  LongTextState copyWith({String? title, String? text}) {
    return LongTextState(
      title: title ?? this.title,
      text: text ?? this.text,
    );
  }
}

class LongTextController extends Cubit<LongTextState> {
  final LongTextParams params;

  LongTextController(this.params) : super(const LongTextState()) {
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
    Rect? sharePositionOrigin;
    if (context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    final file = File(params.path);
    if (await file.exists()) {
      final name = this.params.title;
      final params = ShareParams(
        files: [XFile(file.path)],
        fileNameOverrides: [name],
        sharePositionOrigin: sharePositionOrigin,
      );
      final result = await SharePlus.instance.share(params);

      if (result.status == ShareResultStatus.success) {
        if (context.mounted) {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.actionResult(
              AppLocalizations.of(context)!.longTextPageShare,
              AppLocalizations.of(context)!.resultSuccess,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.actionResult(
              AppLocalizations.of(context)!.longTextPageShare,
              AppLocalizations.of(context)!.resultFailed,
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.longTextPageFileNotExist,
        );
      }
    }
  }
}
