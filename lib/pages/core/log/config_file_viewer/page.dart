import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/log/config_file_viewer/controller.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ConfigFileViewerPage extends StatelessWidget {
  final ConfigFileViewerParams params;

  const ConfigFileViewerPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConfigFileViewerController(params),
      child: BlocBuilder<ConfigFileViewerController, ConfigFileViewerPageState>(
        builder: (context, state) {
          final controller = context.read<ConfigFileViewerController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(state.title),
              actions: [
                if (!AppPlatform.isLinux)
                  IconButton(
                    tooltip: AppLocalizations.of(
                      context,
                    )!.configFileViewerPageShare,
                    onPressed: () => controller.shareFile(context),
                    icon: const Icon(LucideIcons.share2),
                  ),
              ],
            ),
            body: SafeArea(child: SelectionArea(child: _body(context, state))),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, ConfigFileViewerPageState state) {
    return ResponsiveContent(
      desktopMaxWidth: 1080,
      adaptiveBreakpoint: 840,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(22, 18, 22, 30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: ColorManager.tagBackground(context).withValues(alpha: 0.55),
            border: Border.all(color: ColorManager.border(context)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            state.text,
            style: AppTypography.code.copyWith(
              color: ColorManager.primaryText(context),
            ),
          ),
        ),
      ),
    );
  }
}
