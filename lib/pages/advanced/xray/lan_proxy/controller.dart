import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/xray/lan_proxy/dialog.dart';
import 'package:onexray/service/advanced/policy_editor.dart';

class LanProxyController extends PolicyEditorController {
  LanProxyController({super.draft, PolicyEditorService? service})
    : super(service: service ?? PolicyEditorService(validateInterface: false)) {
    if (draft != null) _readPort();
  }

  final portController = TextEditingController();

  void _readPort() {
    portController.text = '${group('lanProxy')['port']}';
  }

  @override
  Future<void> load(BuildContext context) async {
    await super.load(context);
    if (isPageActive && draft != null) _readPort();
  }

  @override
  String saveLabel(AppLocalizations l) =>
      connected && draft?.original.policy.lanProxyEnabled == true
      ? l.prototypeSaveAndReconnect
      : l.prototypeSave;

  @override
  Future<bool> save(BuildContext context, {bool pop = true}) {
    if (blocked || runtimeBusy || draft == null) return Future.value(false);
    final port = int.tryParse(portController.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      emit(
        state.copyWith(
          error: AppLocalizations.of(context)!.localApiPortInvalid,
        ),
      );
      return Future.value(false);
    }
    update('port', port, section: 'lanProxy');
    return super.save(context, pop: pop);
  }

  @override
  Future<bool> confirmSave(BuildContext context, bool disconnect) =>
      confirmLanProxyRestart(context);

  @override
  void disposePageResources() {
    portController.dispose();
    super.disposePageResources();
  }
}
