import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';

Future<({String address, String port})?> showDnsServerEditDialog(
  BuildContext context,
  Map<String, dynamic> server,
) async {
  var address = server['address']?.toString() ?? '';
  var port = server['port']?.toString() ?? '';
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return AlertDialog(
        title: Text(l10n.dnsPageServers),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: address,
              onChanged: (value) => address = value,
              decoration: InputDecoration(
                labelText: l10n.dnsServerPageAddress,
                hintText: l10n.dnsServerPageAddressExample,
              ),
            ),
            TextFormField(
              initialValue: port,
              onChanged: (value) => port = value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.dnsServerPagePort,
                hintText: l10n.dnsServerPagePortExample,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.buttonSave),
          ),
        ],
      );
    },
  );
  return accepted == true ? (address: address, port: port) : null;
}
