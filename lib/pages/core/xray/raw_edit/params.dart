class XrayRawEditParams {
  final String title;
  final String text;
  final String? Function(String text)? validator;

  XrayRawEditParams(this.title, this.text, {this.validator});
}
