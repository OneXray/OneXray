enum ShareType { config, subscription, geoData }

class SharePageParams {
  final ShareType type;
  final int id;

  SharePageParams(this.type, this.id);
}
