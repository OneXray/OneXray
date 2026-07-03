import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/log/config_file_viewer/controller.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

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
                    onPressed: () => controller.shareFile(context),
                    icon: Icon(Icons.share),
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
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          desktopMaxWidth: 900,
          adaptiveBreakpoint: 840,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(20.0),
            child: Text(state.text),
          ),
        ),
      ),
    );
  }
}
