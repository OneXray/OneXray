import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Compact outbound JSON input used by manual import and server editing.
class OutboundJsonEditor extends StatelessWidget {
  const OutboundJsonEditor({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
        ? 340
        : 290;
    return SizedBox(
      height: height.toDouble(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ShadInput(
          controller: controller,
          textDirection: TextDirection.ltr,
          maxLines: null,
          minLines: null,
          expands: true,
          editableTextSize: Size(double.infinity, height - 28),
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.multiline,
          style: AppTypography.importJson,
          padding: const EdgeInsets.all(13),
          decoration: ShadDecoration(
            color: ColorManager.palette(context).muted,
          ),
        ),
      ),
    );
  }
}
