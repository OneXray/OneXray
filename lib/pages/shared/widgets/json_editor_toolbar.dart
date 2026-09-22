import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';

/// Adapts re_editor's selection operations to the platform's editing menu.
class AppJsonEditorToolbar implements SelectionToolbarController {
  final _clipboard = ClipboardStatusNotifier();
  final _desktop = ContextMenuController();
  late final _mobile = MobileSelectionToolbarController(builder: _buildToolbar);

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    _clipboard.update();
    // re_editor supplies a render rect only for its mobile selection overlay.
    if (renderRect != null) {
      _mobile.show(
        context: context,
        controller: controller,
        anchors: anchors,
        renderRect: renderRect,
        layerLink: layerLink,
        visibility: visibility,
      );
    } else {
      _desktop.show(
        context: context,
        contextMenuBuilder: (_) => CodeEditorTapRegion(
          onTapOutside: (_) => hide(context),
          child: _buildToolbar(
            context: context,
            anchors: anchors,
            controller: controller,
            onDismiss: () => hide(context),
            onRefresh: _desktop.markNeedsBuild,
          ),
        ),
      );
    }
  }

  Widget _buildToolbar({
    required BuildContext context,
    required TextSelectionToolbarAnchors anchors,
    required CodeLineEditingController controller,
    required VoidCallback onDismiss,
    required VoidCallback onRefresh,
  }) {
    return InheritedTheme.captureAll(
      context,
      ValueListenableBuilder<ClipboardStatus>(
        valueListenable: _clipboard,
        builder: (context, clipboard, _) =>
            AdaptiveTextSelectionToolbar.buttonItems(
              anchors: anchors,
              buttonItems: [
                if (!controller.selection.isCollapsed) ...[
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.cut,
                    onPressed: () {
                      onDismiss();
                      controller.cut();
                    },
                  ),
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    onPressed: () {
                      onDismiss();
                      controller.copy();
                    },
                  ),
                ],
                if (clipboard == ClipboardStatus.pasteable)
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.paste,
                    onPressed: () {
                      onDismiss();
                      controller.paste();
                    },
                  ),
                if (controller.text.isNotEmpty && !controller.isAllSelected)
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.selectAll,
                    onPressed: () {
                      controller.selectAll();
                      onRefresh();
                    },
                  ),
              ],
            ),
      ),
    );
  }

  @override
  void hide(BuildContext context) {
    _mobile.hide(context);
    _desktop.remove();
  }

  void dispose() {
    _desktop.remove();
    _clipboard.dispose();
  }
}
