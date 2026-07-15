import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SubscriptionFormView extends StatelessWidget {
  const SubscriptionFormView({
    super.key,
    required this.supportText,
    required this.nameLabel,
    required this.nameController,
    required this.urlLabel,
    this.urlController,
    this.readOnlyUrl,
    this.urlHint,
    this.urlHelper,
    this.autoUpdateTitle,
    this.autoUpdateValue,
    this.onOpenAutoUpdate,
  }) : assert(urlController != null || readOnlyUrl != null);

  final String supportText;
  final String nameLabel;
  final TextEditingController nameController;
  final String urlLabel;
  final TextEditingController? urlController;
  final String? readOnlyUrl;
  final String? urlHint;
  final String? urlHelper;
  final String? autoUpdateTitle;
  final String? autoUpdateValue;
  final VoidCallback? onOpenAutoUpdate;

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
              final url = urlController == null
                  ? _readOnlyField(context)
                  : _editableField(
                      context,
                      label: urlLabel,
                      controller: urlController!,
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

  Widget _readOnlyField(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(context, urlLabel),
          const SizedBox(height: 8),
          Text(
            readOnlyUrl ?? "",
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.rowTitle.copyWith(
              color: ColorManager.primaryText(context),
            ),
          ),
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
