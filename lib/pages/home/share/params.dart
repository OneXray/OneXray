enum ShareType {
  config,
  subscription,
  geoDat;
}

class SharePageParams {
  final ShareType type;
  final int id;

  SharePageParams(this.type, this.id);
}
