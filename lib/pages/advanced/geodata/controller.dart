import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart'
    show ConnectCallout, ConnectDialogButton;
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/validator.dart';

class GeoDataController extends ChangeNotifier {
  GeoDataController({GeoDataService? service})
    : service = service ?? GeoDataService();
  final GeoDataService service;
  final name = TextEditingController();
  final url = TextEditingController();
  GeoDataType type = GeoDataType.ip;
  List<PublishedGeoData> files = const [];
  final Map<int, String> errors = {};
  String? formError;
  bool loading = true;
  bool failed = false;
  bool formBusy = false;
  bool updatingAll = false;
  final Set<int> updating = {};
  final Set<int> deleting = {};
  bool adding = false;
  bool _disposed = false;
  StreamSubscription<List<PublishedGeoData>>? _subscription;

  List<PublishedGeoData> get defaults =>
      files.where((file) => file.builtIn).toList();
  List<PublishedGeoData> get custom =>
      files.where((file) => !file.builtIn).toList();

  bool get canUpdateAll => !updatingAll && updating.isEmpty && deleting.isEmpty;
  bool fileBusy(int id) =>
      updatingAll || updating.contains(id) || deleting.contains(id);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    failed = false;
    _changed();
    try {
      await service.ensureInstalled();
      if (_disposed) return;
      await _subscription?.cancel();
      _subscription = service.watchPublished().listen(
        (value) {
          files = value;
          loading = false;
          failed = false;
          _changed();
        },
        onError: (_) {
          loading = false;
          failed = true;
          _changed();
        },
      );
    } catch (_) {
      loading = false;
      failed = true;
      _changed();
    }
  }

  void toggleAdd() {
    if (formBusy) return;
    adding = !adding;
    formError = null;
    if (!adding) {
      name.clear();
      url.clear();
    }
    _changed();
  }

  void changeType(GeoDataType? value) {
    if (value == null || formBusy) return;
    type = value;
    _changed();
  }

  Future<void> add(BuildContext context) async {
    if (formBusy) return;
    final l = AppLocalizations.of(context)!;
    final input = GeoDataInput(fileName: name.text, type: type, url: url.text);
    formBusy = true;
    formError = null;
    _changed();
    try {
      final validation = await GeoDataValidator.validate(
        input.fileName.trim(),
        input.url.trim(),
      );
      if (_disposed) return;
      if (!validation.item1) {
        formError = validation.item2;
        return;
      }
      await service.add(input);
      if (_disposed) return;
      adding = false;
      name.clear();
      url.clear();
      if (context.mounted) _message(context, l.prototypeGeodataAdded);
    } catch (_) {
      formError = l.prototypeCheckNetwork;
    } finally {
      formBusy = false;
      _changed();
    }
  }

  Future<void> update(BuildContext context, PublishedGeoData? file) async {
    final key = file == null || file.builtIn ? -1 : file.row.id;
    if (fileBusy(key)) return;
    final l = AppLocalizations.of(context)!;
    updating.add(key);
    errors.remove(key);
    _changed();
    try {
      if (file == null || file.builtIn) {
        await service.updateDefaults();
      } else {
        await service.updateCustom(file.row);
      }
      if (context.mounted) _message(context, l.prototypeGeodataUpdated);
    } catch (_) {
      errors[key] = l.prototypeCheckNetwork;
    } finally {
      updating.remove(key);
      _changed();
    }
  }

  Future<void> updateAll(BuildContext context) async {
    if (!canUpdateAll) return;
    final l = AppLocalizations.of(context)!;
    final targets = custom.toList();
    updatingAll = true;
    errors.clear();
    _changed();
    try {
      try {
        await service.updateDefaults();
      } catch (_) {
        errors[-1] = l.prototypeCheckNetwork;
      }
      for (final file in targets) {
        try {
          await service.updateCustom(file.row);
        } catch (_) {
          errors[file.row.id] = l.prototypeCheckNetwork;
        }
      }
      if (errors.isEmpty && context.mounted) {
        _message(context, l.prototypeAllGeodataUpdated);
      }
    } finally {
      updatingAll = false;
      _changed();
    }
  }

  Future<void> delete(BuildContext context, PublishedGeoData file) async {
    if (fileBusy(file.row.id) || file.builtIn) return;
    final l = AppLocalizations.of(context)!;
    deleting.add(file.row.id);
    _changed();
    try {
      final confirmed = await showAppDialog<bool>(
        context,
        (context) => AppDialog(
          title: l.prototypeDeleteCustomDatasetQuestion,
          subtitle: file.fileName,
          expandLastAction: false,
          body: ConnectCallout(
            icon: LucideIcons.circleAlert,
            text: l.prototypeDeleteDatasetWarning,
            warning: true,
          ),
          actions: [
            ConnectDialogButton(
              onPressed: () => Navigator.pop(context, false),
              label: l.prototypeCancel,
              secondary: true,
            ),
            ConnectDialogButton(
              onPressed: () => Navigator.pop(context, true),
              label: l.prototypeDelete,
              icon: LucideIcons.trash2,
              destructive: true,
            ),
          ],
        ),
      );
      if (confirmed != true || _disposed) return;
      errors.remove(file.row.id);
      await service.deleteGeoDat(file.row);
    } catch (_) {
      errors[file.row.id] = l.prototypeCheckNetwork;
    } finally {
      deleting.remove(file.row.id);
      _changed();
    }
  }

  static void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    name.dispose();
    url.dispose();
    super.dispose();
  }
}

class GeoDataFileController extends ChangeNotifier {
  GeoDataFileController(this.fileId, {GeoDataService? service})
    : service = service ?? GeoDataService();
  final int fileId;
  final GeoDataService service;
  final search = TextEditingController();
  PublishedGeoData? file;
  bool loading = true;
  bool failed = false;
  bool _disposed = false;
  StreamSubscription<List<PublishedGeoData>>? _subscription;

  List<XrayGeoListCodes> get codes {
    final query = search.text.trim().toLowerCase();
    return (file?.index.codes ?? [])
        .where((entry) => entry.code!.toLowerCase().contains(query))
        .toList();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void searchChanged(String _) => _changed();
  void initialize() {
    _subscription = service.watchPublished().listen(
      (value) {
        file = value.where((item) => item.row.id == fileId).firstOrNull;
        loading = false;
        failed = false;
        _changed();
      },
      onError: (_) {
        loading = false;
        failed = true;
        _changed();
      },
    );
  }

  Future<void> copy(BuildContext context, String value, String success) async {
    final l = AppLocalizations.of(context)!;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) GeoDataController._message(context, success);
    } catch (_) {
      if (context.mounted) {
        GeoDataController._message(context, l.prototypeCopyFailed);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    search.dispose();
    super.dispose();
  }
}
