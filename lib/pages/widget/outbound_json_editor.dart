import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/json_editor.dart';
import 'package:re_editor/re_editor.dart';

/// Compact outbound JSON input used by manual import and server editing.
class OutboundJsonEditor extends StatelessWidget {
  const OutboundJsonEditor({super.key, required this.controller});

  final CodeLineEditingController controller;

  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
        ? 340
        : 290;
    return SizedBox(
      height: height.toDouble(),
      child: AppJsonEditor(
        controller: controller,
        textStyle: AppTypography.importJson,
      ),
    );
  }
}
