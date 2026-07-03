import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/log/log_file_viewer/controller.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/theme/color.dart';

class LogFileViewerPage extends StatelessWidget {
  final LogFileViewerParams params;

  const LogFileViewerPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LogFileViewerController(params),
      child: const _LogFileViewerScaffold(),
    );
  }
}

class _LogFileViewerScaffold extends StatefulWidget {
  const _LogFileViewerScaffold();

  @override
  State<_LogFileViewerScaffold> createState() => _LogFileViewerScaffoldState();
}

class _LogFileViewerScaffoldState extends State<_LogFileViewerScaffold> {
  final _scrollController = ScrollController();
  var _autoScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LogFileViewerController, LogFileViewerPageState>(
      listenWhen: (previous, current) =>
          current.followTail &&
          (previous.lines.length != current.lines.length ||
              previous.followTail != current.followTail),
      listener: (_, _) => _scrollToBottom(),
      builder: (context, state) {
        final controller = context.read<LogFileViewerController>();
        return Scaffold(
          appBar: AppBar(title: Text(state.title)),
          body: SafeArea(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _handleScrollNotification(controller, notification);
                    return false;
                  },
                  child: _body(context, state),
                ),
                if (!state.followTail)
                  PositionedDirectional(
                    end: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: () {
                        controller.setFollowTail(true);
                        _scrollToBottom();
                      },
                      icon: const Icon(Icons.south),
                      label: Text(
                        AppLocalizations.of(
                          context,
                        )!.logFileViewerContinueFollowing,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, LogFileViewerPageState state) {
    if (!state.fileExists) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.logFileViewerFileNotExist,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 20),
      itemCount: state.lines.length + (state.truncated ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.truncated && index == 0) {
          return _recentLogHint(context);
        }
        final lineIndex = state.truncated ? index - 1 : index;
        return Text(
          state.lines[lineIndex],
          style: TextStyle(
            fontFamily: "monospace",
            fontSize: GlobalConstants.bodyFontSize,
            height: 1.35,
            color: ColorManager.primaryText(context),
          ),
        );
      },
    );
  }

  Widget _recentLogHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Text(
        AppLocalizations.of(context)!.logFileViewerShowingRecent,
        style: TextStyle(
          fontSize: 12,
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }

  void _handleScrollNotification(
    LogFileViewerController controller,
    ScrollNotification notification,
  ) {
    if (_autoScrolling || notification is! ScrollUpdateNotification) {
      return;
    }
    if (notification.dragDetails == null) {
      return;
    }
    controller.setFollowTail(notification.metrics.extentAfter < 48);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _autoScrolling = true;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _autoScrolling = false;
    });
  }
}
