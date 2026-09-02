class LogFileViewerParams {
  final String title;
  final String path;
  final String? systemExtensionPlanId;
  final bool access;

  const LogFileViewerParams({
    required this.title,
    required this.path,
    this.systemExtensionPlanId,
    this.access = true,
  });
}
