enum ShareType { config, subscription }

class SharePageParams {
  final ShareType type;
  final int id;

  SharePageParams(this.type, this.id);
}
