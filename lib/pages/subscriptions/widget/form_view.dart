import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SubscriptionFormView extends StatelessWidget {
  const SubscriptionFormView({
    super.key,
    required this.supportText,
    required this.nameLabel,
    required this.nameController,
    required this.urlLabel,
    required this.urlController,
    this.urlHint,
    this.urlHelper,
    this.autoUpdateTitle,
    this.autoUpdateValue,
    this.onOpenAutoUpdate,
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
    this.onAgeKeyChanged,
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
    this.generatingAgeKey = false,
  });

  final String supportText;
  final String nameLabel;
  final TextEditingController nameController;
  final String urlLabel;
  final TextEditingController urlController;
  final String? urlHint;
  final String? urlHelper;
  final String? autoUpdateTitle;
  final String? autoUpdateValue;
  final VoidCallback? onOpenAutoUpdate;
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
  final ValueChanged<String>? onAgeKeyChanged;
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
  final bool generatingAgeKey;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsiveContent(
        desktopMaxWidth: 820,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
          child: Column(
            children: [
              _formCard(context),
              const SizedBox(height: 18),
              _encryptionCard(context),
              if (onOpenAutoUpdate != null) ...[
                const SizedBox(height: 18),
                _autoUpdateCard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _encryptionCard(BuildContext context) {
    return ShadCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      radius: const BorderRadius.all(Radius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
            child: Text(encryptionTitle, style: AppTypography.sectionTitle),
          ),
          Divider(height: 1, color: ColorManager.border(context)),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ageProviderSupportAlert(context),
                const SizedBox(height: 14),
                _fieldLabel(context, ageSecretKeyLabel),
                const SizedBox(height: 8),
                ShadInput(
                  controller: ageSecretKeyController,
                  obscureText: obscureAgeSecretKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: onAgeKeyChanged,
                  placeholder: Text(ageSecretKeyHint),
                  trailing: IconButton(
                    tooltip: obscureAgeSecretKey
                        ? revealAgeSecretKeyLabel
                        : hideAgeSecretKeyLabel,
                    onPressed: onToggleAgeSecretKeyVisibility,
                    icon: Icon(
                      obscureAgeSecretKey
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _fieldLabel(context, agePublicKeyLabel),
                const SizedBox(height: 8),
                ShadInput(
                  controller: agePublicKeyController,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: onAgeKeyChanged,
                  placeholder: Text(agePublicKeyHint),
                ),
                if (ageKeyPairErrorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    ageKeyPairErrorText!,
                    style: AppTypography.badge.copyWith(
                      color: ColorManager.palette(context).destructive,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppMenuButton<AgeKeyType>(
                      entries: [
                        AppMenuEntry<AgeKeyType>.item(
                          value: AgeKeyType.x25519,
                          title: generateAgeX25519KeyLabel,
                        ),
                        AppMenuEntry<AgeKeyType>.item(
                          value: AgeKeyType.hybrid,
                          title: generateAgeHybridKeyLabel,
                        ),
                      ],
                      onSelected: onGenerateAgeKey,
                      triggerBuilder: (toggleMenu) => ShadButton.outline(
                        leading: generatingAgeKey
                            ? const SizedBox.square(
                                dimension: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.keyRound),
                        onPressed: generatingAgeKey ? null : toggleMenu,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(generateAgeKeyLabel),
                            if (!generatingAgeKey) ...[
                              const SizedBox(width: 6),
                              const Icon(LucideIcons.chevronDown, size: 15),
                            ],
                          ],
                        ),
                      ),
                    ),
                    ShadButton.ghost(
                      leading: const Icon(LucideIcons.trash2),
                      onPressed: generatingAgeKey ? null : onClearAgeKey,
                      child: Text(clearAgeKeyLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ageProviderSupportAlert(BuildContext context) {
    final palette = ColorManager.palette(context);
    return ShadAlert(
      icon: const Icon(LucideIcons.triangleAlert),
      title: Text(ageProviderSupportTitle),
      description: Text(ageProviderSupportDescription),
      iconColor: palette.restartingText,
      titleStyle: AppTypography.listSectionTitle.copyWith(
        color: palette.restartingText,
        fontWeight: FontWeight.w600,
      ),
      descriptionStyle: AppTypography.supporting.copyWith(
        color: palette.foreground,
      ),
      decoration: ShadDecoration(
        color: palette.restarting.withValues(alpha: 0.08),
        border: ShadBorder.all(
          color: palette.restarting.withValues(alpha: 0.42),
          radius: const BorderRadius.all(Radius.circular(8)),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    return ShadCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      radius: const BorderRadius.all(Radius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
            child: Text(
              supportText,
              style: AppTypography.supporting.copyWith(
                color: ColorManager.secondaryText(context),
              ),
            ),
          ),
          Divider(height: 1, color: ColorManager.border(context)),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final name = _editableField(
                context,
                label: nameLabel,
                controller: nameController,
                hintText: nameLabel,
              );
              final url = _editableField(
                context,
                label: urlLabel,
                controller: urlController,
                hintText: urlHint,
                helperText: urlHelper,
              );
              if (compact) {
                return Column(
                  children: [
                    name,
                    Divider(height: 1, color: ColorManager.border(context)),
                    url,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: name),
                    VerticalDivider(
                      width: 1,
                      color: ColorManager.border(context),
                    ),
                    Expanded(flex: 13, child: url),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _editableField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(context, label),
          const SizedBox(height: 8),
          ShadInput(
            controller: controller,
            placeholder: hintText == null ? null : Text(hintText),
          ),
          if (helperText != null && helperText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              helperText,
              style: AppTypography.badge.copyWith(
                color: ColorManager.secondaryText(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: AppTypography.supporting.copyWith(
        fontWeight: FontWeight.w600,
        color: ColorManager.secondaryText(context),
      ),
    );
  }

  Widget _autoUpdateCard(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return ShadCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      radius: radius,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenAutoUpdate,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      autoUpdateTitle ?? "",
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  if (autoUpdateValue != null &&
                      autoUpdateValue!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Align(
                        key: const ValueKey("subscriptionAutoUpdateValue"),
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          autoUpdateValue!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: AppTypography.supporting.copyWith(
                            color: ColorManager.secondaryText(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 7),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 17,
                    color: ColorManager.secondaryText(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
