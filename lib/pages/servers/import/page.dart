import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

export 'controller.dart' show ServerImportAction;

export 'package:onexray/service/assets/import.dart' show ServerImportResult;

class ServersImportPage extends StatefulWidget {
  final bool setup;
  final ServerImportAction? initialAction;
  final String? initialText;
  const ServersImportPage({
    super.key,
    this.setup = false,
    this.initialAction,
    this.initialText,
  });

  @override
  State<ServersImportPage> createState() => _ServersImportPageState();
}

class _ServersImportPageState extends State<ServersImportPage> {
  late final controller = ServerImportController();

  @override
  void initState() {
    super.initState();
    final action = widget.initialAction;
    final input = widget.initialText;
    if (action != null || input != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (input != null) {
            controller.openText(context, input);
          } else {
            controller.open(context, action!);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.prototypeAddServers),
            leading: BackButton(onPressed: () => controller.closePage(context)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: ResponsiveContent(
                desktopMaxWidth: 760,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.prototypeChooseAddMethod,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (controller.supportsScan)
                        _choice(
                          context,
                          ServerImportAction.scan,
                          LucideIcons.qrCode,
                          l10n.prototypeScanQrCode,
                        ),
                      _choice(
                        context,
                        ServerImportAction.paste,
                        LucideIcons.clipboardPaste,
                        l10n.prototypePasteLink,
                      ),
                      _choice(
                        context,
                        ServerImportAction.subscription,
                        LucideIcons.link,
                        l10n.prototypeAddSubscription,
                      ),
                      _choice(
                        context,
                        ServerImportAction.file,
                        LucideIcons.fileInput,
                        l10n.prototypeImportFile,
                      ),
                      _choice(
                        context,
                        ServerImportAction.json,
                        LucideIcons.fileJson,
                        l10n.prototypeAddManually,
                      ),
                      if (widget.setup) ...[
                        const SizedBox(height: 16),
                        Text(l10n.prototypeSetupDoesNotStartVpn),
                      ],
                      _ImportFeedback(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _choice(
    BuildContext context,
    ServerImportAction action,
    IconData icon,
    String title,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ShadButton.outline(
      onPressed: controller.busy
          ? null
          : () => controller.open(context, action),
      leading: Icon(icon),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(title),
      ),
    ),
  );
}

class ServerImportFormPage extends StatelessWidget {
  final ServerImportController controller;
  final ServerImportAction action;
  const ServerImportFormPage({
    super.key,
    required this.controller,
    required this.action,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final subscription = action == ServerImportAction.subscription;
      final manual = action == ServerImportAction.json;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              subscription
                  ? controller.editingSubscription
                        ? l10n.prototypeEditSubscription
                        : l10n.prototypeAddSubscription
                  : manual
                  ? l10n.prototypeXrayNodeJson
                  : l10n.prototypePasteLink,
            ),
            leading: BackButton(onPressed: () => controller.closePage(context)),
            actions: [
              if (!subscription)
                IconButton(
                  tooltip: l10n.prototypeReadClipboard,
                  onPressed: controller.busy
                      ? null
                      : () => controller.readClipboard(context),
                  icon: const Icon(LucideIcons.clipboardPaste),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: subscription
                      ? IgnorePointer(
                          ignoring: controller.busy || controller.loadFailed,
                          child: _subscription(context),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: ResponsiveContent(
                            desktopMaxWidth: 900,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  manual
                                      ? l10n.prototypeNodeJsonHint
                                      : l10n.prototypeImportLinksHint,
                                ),
                                if (!manual) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.prototypeSubscriptionDirectImportNotice,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  l10n.prototypeLocalInputPrivacy,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: manual
                                      ? SettingsJsonEditor(
                                          controller: controller.text,
                                          lineCount: controller.lineCount,
                                          valid: controller.validJson,
                                          validLabel: l10n.jsonEditorValid,
                                          invalidLabel: l10n.jsonEditorInvalid,
                                          linesLabel:
                                              '${controller.lineCount} ${l10n.jsonEditorLines}',
                                          spacesLabel: l10n.jsonEditorSpaces,
                                        )
                                      : TextField(
                                          controller: controller.text,
                                          expands: true,
                                          maxLines: null,
                                          minLines: null,
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          keyboardType: TextInputType.multiline,
                                          decoration: InputDecoration(
                                            labelText: l10n.prototypePasteLink,
                                            alignLabelWithHint: true,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                _ImportFeedback(controller: controller),
              ],
            ),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              ShadButton.outline(
                onPressed: controller.busy
                    ? null
                    : () => controller.closePage(context),
                child: Text(l10n.prototypeCancel),
              ),
              ShadButton(
                onPressed: controller.busy || controller.loadFailed
                    ? null
                    : () => subscription
                          ? controller.subscribe(context)
                          : controller.detect(context, action),
                child: Text(
                  subscription
                      ? controller.editingSubscription
                            ? l10n.prototypeSave
                            : l10n.prototypeAddSubscription
                      : l10n.prototypeDetect,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _subscription(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SubscriptionFormView(
      supportText: controller.editingSubscription
          ? l10n.prototypeChangesApplyToFutureUpdates
          : l10n.prototypeSubscriptionDescription,
      nameLabel: l10n.prototypeSubscriptionName,
      nameController: controller.name,
      urlLabel: l10n.prototypeSubscriptionLink,
      urlController: controller.url,
      urlHint: l10n.subscriptionAddPageUrlExample,
      encryptionTitle: l10n.prototypeAgeEncryption,
      ageProviderSupportTitle: l10n.prototypeAgeOptional,
      ageProviderSupportDescription: l10n.prototypeAgeSupportNotice,
      ageSecretKeyLabel: l10n.prototypeAgeSecretKey,
      ageSecretKeyHint: l10n.subscriptionAgeSecretKeyHint,
      ageSecretKeyController: controller.secretKey,
      agePublicKeyLabel: l10n.prototypeAgePublicKey,
      agePublicKeyHint: l10n.subscriptionAgePublicKeyHint,
      agePublicKeyController: controller.publicKey,
      ageKeyPairErrorText: controller.incompleteKeys
          ? l10n.prototypeAgeBothKeysRequired
          : null,
      onAgeKeyChanged: controller.ageChanged,
      obscureAgeSecretKey: controller.obscureSecret,
      revealAgeSecretKeyLabel: l10n.prototypeRevealKey,
      hideAgeSecretKeyLabel: l10n.prototypeHideKey,
      generateAgeKeyLabel: l10n.subscriptionGenerateAgeKey,
      generateAgeX25519KeyLabel: l10n.subscriptionGenerateAgeX25519Key,
      generateAgeHybridKeyLabel: l10n.prototypeAgeHybrid,
      clearAgeKeyLabel: l10n.prototypeClear,
      onToggleAgeSecretKeyVisibility: controller.toggleSecret,
      onGenerateAgeKey: (type) => controller.generateKeys(context, type),
      onClearAgeKey: controller.clearKeys,
      generatingAgeKey: controller.busy,
    );
  }
}

class ServerImportPreviewPage extends StatelessWidget {
  final ServerImportController controller;
  final ServerImportPreview preview;
  const ServerImportPreviewPage({
    super.key,
    required this.controller,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.prototypeImportPreview),
            leading: BackButton(onPressed: () => controller.closePage(context)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: ResponsiveContent(
                desktopMaxWidth: 760,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.prototypeUsableNodes(preview.count),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (controller.committedResult != null &&
                          preview.count > 0)
                        Text(l10n.prototypeServersAdded),
                      for (final raw in preview.rows.where(
                        (row) => row.type.value == 'raw',
                      ))
                        ListTile(
                          leading: const Icon(LucideIcons.fileJson),
                          title: Text(raw.name.value),
                          subtitle: Text(
                            controller.committedResult == null
                                ? l10n.xrayRawPageTitle
                                : l10n.prototypeNameSaved(raw.name.value),
                          ),
                        ),
                      for (final source in preview.geoData)
                        ListTile(
                          leading: const Icon(LucideIcons.database),
                          title: Text(source.name),
                          subtitle: Text(
                            controller.committedResult == null
                                ? l10n.prototypeDataSource
                                : controller.committedResult!.failedGeoData
                                      .contains(source)
                                ? l10n.prototypeCannotReadContent
                                : l10n.prototypeGeodataAdded,
                          ),
                        ),
                      if (preview.failureCount != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.prototypeUnrecognizedNodes(
                            preview.failureCount!,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (!preview.hasItems)
                        Text(l10n.prototypeNoSupportedLinks),
                      Text(l10n.prototypeLocalInputPrivacy),
                      _ImportFeedback(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              ShadButton.outline(
                onPressed: controller.busy
                    ? null
                    : () => controller.closePage(context),
                child: Text(
                  controller.committedResult == null
                      ? l10n.prototypeCancel
                      : l10n.prototypeClose,
                ),
              ),
              ShadButton(
                onPressed: controller.busy || !preview.hasItems
                    ? null
                    : () => controller.confirm(context, preview),
                child: Text(
                  controller.committedResult == null
                      ? l10n.prototypeConfirmAdd
                      : l10n.prototypeDone,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ServerImportScannerPage extends StatelessWidget {
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onPickImage;
  const ServerImportScannerPage({
    super.key,
    required this.onDetect,
    required this.onPickImage,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context)!.prototypeScanQrCode),
      actions: [
        IconButton(
          tooltip: AppLocalizations.of(context)!.menuPickImage,
          onPressed: onPickImage,
          icon: const Icon(LucideIcons.image),
        ),
      ],
    ),
    body: SafeArea(child: MobileScanner(onDetect: onDetect)),
  );
}

class _ImportFeedback extends StatelessWidget {
  final ServerImportController controller;
  const _ImportFeedback({required this.controller});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.25,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (controller.busy) const LinearProgressIndicator(),
            if (controller.importedSubscriptionCount > 0)
              Text(
                AppLocalizations.of(context)!.prototypeSubscriptionsImported(
                  controller.importedSubscriptionCount,
                ),
              ),
            for (final item in controller.subscriptionImports)
              Text(
                item.result.success
                    ? item.result.parseFailureCount == null
                          ? '${item.name}: ${AppLocalizations.of(context)!.prototypeUsableNodes(item.result.count)}'
                          : AppLocalizations.of(context)!
                                .prototypeSubscriptionImportResult(
                                  item.name,
                                  item.result.count,
                                  item.result.parseFailureCount!,
                                )
                    : '${item.name}: ${ServerImportController.subscriptionError(AppLocalizations.of(context)!, item.result.status)}',
              ),
            if (controller.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  controller.error!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
