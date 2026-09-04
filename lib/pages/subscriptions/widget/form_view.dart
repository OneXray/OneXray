import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SubscriptionFormView extends StatelessWidget {
  const SubscriptionFormView({
    super.key,
    required this.supportText,
    required this.nameLabel,
    required this.nameController,
    this.nameHint,
    required this.urlLabel,
    required this.urlController,
    this.urlHint,
    this.urlHelper,
    required this.encryptionTitle,
    required this.ageProviderSupportTitle,
    required this.ageProviderSupportDescription,
    required this.ageSecretKeyLabel,
    required this.ageSecretKeyHint,
    required this.ageSecretKeyController,
    required this.agePublicKeyLabel,
    required this.agePublicKeyHint,
    required this.agePublicKeyController,
    this.ageKeyPairErrorText,
    required this.obscureAgeSecretKey,
    required this.revealAgeSecretKeyLabel,
    required this.hideAgeSecretKeyLabel,
    required this.generateAgeKeyLabel,
    required this.generateAgeX25519KeyLabel,
    required this.generateAgeHybridKeyLabel,
    required this.clearAgeKeyLabel,
    required this.onToggleAgeSecretKeyVisibility,
    required this.onGenerateAgeKey,
    required this.onClearAgeKey,
    this.generatingAgeKeyType,
    this.ageKeyActionsEnabled = true,
    required this.hasAgeKeys,
    required this.ageExpanded,
    required this.onToggleAgeExpanded,
  });

  final String supportText;
  final String nameLabel;
  final TextEditingController nameController;
  final String? nameHint;
  final String urlLabel;
  final TextEditingController urlController;
  final String? urlHint;
  final String? urlHelper;
  final String encryptionTitle;
  final String ageProviderSupportTitle;
  final String ageProviderSupportDescription;
  final String ageSecretKeyLabel;
  final String ageSecretKeyHint;
  final TextEditingController ageSecretKeyController;
  final String agePublicKeyLabel;
  final String agePublicKeyHint;
  final TextEditingController agePublicKeyController;
  final String? ageKeyPairErrorText;
  final bool obscureAgeSecretKey;
  final String revealAgeSecretKeyLabel;
  final String hideAgeSecretKeyLabel;
  final String generateAgeKeyLabel;
  final String generateAgeX25519KeyLabel;
  final String generateAgeHybridKeyLabel;
  final String clearAgeKeyLabel;
  final VoidCallback onToggleAgeSecretKeyVisibility;
  final ValueChanged<AgeKeyType> onGenerateAgeKey;
  final VoidCallback onClearAgeKey;
  final AgeKeyType? generatingAgeKeyType;
  final bool ageKeyActionsEnabled;
  final bool hasAgeKeys;
  final bool ageExpanded;
  final VoidCallback onToggleAgeExpanded;
  bool get generatingAgeKey => generatingAgeKeyType != null;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _fields(context),
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
              ? 4
              : 0,
        ).copyWith(top: 12),
        child: _notice(context, supportText),
      ),
      const SizedBox(height: 14),
      _encryptionCard(context),
    ],
  );

  Widget _fields(BuildContext context) {
    final fields = [
      _editableField(
        context,
        label: nameLabel,
        controller: nameController,
        hintText: nameHint ?? nameLabel,
      ),
      _editableField(
        context,
        label: urlLabel,
        controller: urlController,
        hintText: urlHint,
        helperText: urlHelper,
        textDirection: TextDirection.ltr,
        keyboardType: TextInputType.url,
      ),
    ];
    if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      return Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: fields,
      );
    }
    return Row(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: fields[0]),
        Expanded(flex: 5, child: fields[1]),
      ],
    );
  }

  Widget _notice(BuildContext context, String text, {bool warning = false}) {
    final palette = ColorManager.palette(context);
    return Container(
      padding: EdgeInsets.all(warning ? 10 : 12),
      decoration: BoxDecoration(
        color: warning ? palette.warningSurface : palette.selectedSurface,
        borderRadius: BorderRadius.circular(
          warning ? AppRadii.control : AppRadii.card,
        ),
      ),
      child: Row(
        spacing: warning ? 8 : 10,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: warning ? 17 : 18,
            color: warning ? palette.restarting : palette.primary,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  (warning
                          ? AppTypography.subscriptionAgeWarning
                          : AppTypography.subscriptionInfo)
                      .copyWith(color: palette.mutedStrong),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encryptionCard(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: ageExpanded,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.card),
              onTap: onToggleAgeExpanded,
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        spacing: 3,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            encryptionTitle,
                            style: AppTypography.subscriptionAgeTitle,
                          ),
                          Text(
                            ageProviderSupportTitle,
                            style: AppTypography.subscriptionAgeOptional
                                .copyWith(color: palette.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      ageExpanded
                          ? LucideIcons.arrowDown
                          : LucideIcons.arrowRightDir,
                      size: 18,
                      textDirection: Directionality.of(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (ageExpanded) ...[
            Divider(height: 0, color: palette.border),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _notice(
                    context,
                    ageProviderSupportDescription,
                    warning: true,
                  ),
                  Column(
                    spacing: 7,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fieldLabel(context, ageSecretKeyLabel),
                      Row(
                        spacing: 6,
                        children: [
                          Expanded(
                            child: _input(
                              context,
                              controller: ageSecretKeyController,
                              hintText: ageSecretKeyHint,
                              obscureText: obscureAgeSecretKey,
                              enabled: !generatingAgeKey,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          IconButton(
                            tooltip: obscureAgeSecretKey
                                ? revealAgeSecretKeyLabel
                                : hideAgeSecretKeyLabel,
                            onPressed: onToggleAgeSecretKeyVisibility,
                            style: IconButton.styleFrom(
                              foregroundColor: palette.mutedStrong,
                              minimumSize: const Size.square(36),
                              maximumSize: const Size.square(36),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              obscureAgeSecretKey
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _editableField(
                    context,
                    label: agePublicKeyLabel,
                    controller: agePublicKeyController,
                    hintText: agePublicKeyHint,
                    enabled: !generatingAgeKey,
                    textDirection: TextDirection.ltr,
                  ),
                  if (ageKeyPairErrorText != null)
                    Text(
                      ageKeyPairErrorText!,
                      style: AppTypography.subscriptionAgeWarning.copyWith(
                        color: palette.destructive,
                      ),
                    ),
                  _keyActions(context),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _keyActions(BuildContext context) {
    final palette = ColorManager.palette(context);
    Widget generate(AgeKeyType type, String label) => OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.foreground,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: AppTypography.subscriptionAgeAction,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
      onPressed: generatingAgeKey || !ageKeyActionsEnabled
          ? null
          : () => onGenerateAgeKey(type),
      icon: generatingAgeKeyType == type
          ? const ButtonProgressIndicator()
          : const Icon(LucideIcons.keyRound, size: 16),
      label: Text(label),
    );
    final generators = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        generate(AgeKeyType.x25519, generateAgeX25519KeyLabel),
        generate(AgeKeyType.hybrid, generateAgeHybridKeyLabel),
      ],
    );
    final clear = TextButton(
      onPressed: generatingAgeKey || !ageKeyActionsEnabled || !hasAgeKeys
          ? null
          : onClearAgeKey,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: AppTypography.subscriptionClear,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(clearAgeKeyLabel),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: generateAgeKeyLabel,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 400
            ? Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  generators,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: clear,
                  ),
                ],
              )
            : Row(
                spacing: 8,
                children: [
                  Expanded(child: generators),
                  clear,
                ],
              ),
      ),
    );
  }

  Widget _input(
    BuildContext context, {
    required TextEditingController controller,
    String? hintText,
    TextDirection? textDirection,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    final palette = ColorManager.palette(context);
    return Directionality(
      textDirection: textDirection ?? Directionality.of(context),
      child: ShadInput(
        enabled: enabled,
        controller: controller,
        placeholder: hintText == null ? null : Text(hintText),
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        style: AppTypography.subscriptionField,
        placeholderStyle: AppTypography.subscriptionField.copyWith(
          color: palette.mutedForeground,
        ),
        textDirection: textDirection,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: onChanged,
        decoration: ShadDecoration(
          border: ShadBorder.all(
            color: palette.border,
            radius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),
    );
  }

  Widget _editableField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? helperText,
    TextDirection? textDirection,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) {
    return Column(
      spacing: 7,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(context, label),
        _input(
          context,
          controller: controller,
          hintText: hintText,
          textDirection: textDirection,
          keyboardType: keyboardType,
          onChanged: onChanged,
          enabled: enabled,
        ),
        if (helperText != null && helperText.isNotEmpty)
          Text(
            helperText,
            style: AppTypography.subscriptionAgeWarning.copyWith(
              color: ColorManager.palette(context).mutedForeground,
            ),
          ),
      ],
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: AppTypography.subscriptionField.copyWith(
        color: ColorManager.palette(context).mutedStrong,
      ),
    );
  }
}
