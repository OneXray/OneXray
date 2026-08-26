import 'package:json_annotation/json_annotation.dart';

part 'xray_inbound_account.g.dart';

@JsonSerializable(includeIfNull: false)
class XrayInboundAccount {
  String? user;
  String? pass;

  XrayInboundAccount(this.user, this.pass);

  factory XrayInboundAccount.fromJson(Map<String, dynamic> json) =>
      _$XrayInboundAccountFromJson(json);

  Map<String, dynamic> toJson() => _$XrayInboundAccountToJson(this);
}
