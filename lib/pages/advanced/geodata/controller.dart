import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart'
    show ConnectCallout, ConnectDialogButton;
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/validator.dart';

@immutable
class GeoDataPageState {
  GeoDataPageState({
    List<PublishedGeoData> files = const [],
    Map<int, String> errors = const {},
    this.formError,
    this.type = GeoDataType.ip,
    this.loading = true,
    this.failed = false,
    this.formBusy = false,
    this.updatingAll = false,
    Set<int> updating = const {},
    Set<int> deleting = const {},
    this.adding = false,
  }) : files = List.unmodifiable(files),
       errors = Map.unmodifiable(errors),
       updating = Set.unmodifiable(updating),
       deleting = Set.unmodifiable(deleting);

  final List<PublishedGeoData> files;
  final Map<int, String> errors;
  final String? formError;
  final GeoDataType type;
  final bool loading;
  final bool failed;
  final bool formBusy;
  final bool updatingAll;
  final Set<int> updating;
  final Set<int> deleting;
  final bool adding;

  List<PublishedGeoData> get defaults =>
      files.where((file) => file.builtIn).toList(growable: false);
  List<PublishedGeoData> get custom =>
      files.where((file) => !file.builtIn).toList(growable: false);
  bool get canUpdateAll => !updatingAll && updating.isEmpty && deleting.isEmpty;
  bool fileBusy(int id) =>
      updatingAll || updating.contains(id) || deleting.contains(id);

  GeoDataPageState copyWith({
    List<PublishedGeoData>? files,
    Map<int, String>? errors,
    String? formError,
    bool clearFormError = false,
    GeoDataType? type,
    bool? loading,
    bool? failed,
    bool? formBusy,
    bool? updatingAll,
    Set<int>? updating,
    Set<int>? deleting,
    bool? adding,
  }) => GeoDataPageState(
    files: files ?? this.files,
    errors: errors ?? this.errors,
    formError: clearFormError ? null : formError ?? this.formError,
    type: type ?? this.type,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    formBusy: formBusy ?? this.formBusy,
    updatingAll: updatingAll ?? this.updatingAll,
    updating: updating ?? this.updating,
    deleting: deleting ?? this.deleting,
    adding: adding ?? this.adding,
  );
}

class GeoDataController extends PageCubit<GeoDataPageState> {
  GeoDataController({GeoDataService? service})
    : service = service ?? GeoDataService(),
      super(GeoDataPageState());

  final GeoDataService service;
  final name = TextEditingController();
  final url = TextEditingController();
  StreamSubscription<List<PublishedGeoData>>? _subscription;

  Future<void> initialize() async {
    emit(state.copyWith(loading: true, failed: false));
    try {
      await service.ensureInstalled();
      if (!isPageActive) return;
      await _subscription?.cancel();
      if (!isPageActive) return;
      _subscription = service.watchPublished().listen(
        (files) =>
            emit(state.copyWith(files: files, loading: false, failed: false)),
        onError: (_) => emit(state.copyWith(loading: false, failed: true)),
      );
    } catch (_) {
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  void toggleAdd() {
    if (state.formBusy) return;
    final adding = !state.adding;
    if (!adding) {
      name.clear();
      url.clear();
    }
    emit(state.copyWith(adding: adding, clearFormError: true));
  }

  void changeType(GeoDataType? value) {
    if (value == null || state.formBusy) return;
    emit(state.copyWith(type: value));
  }

  Future<void> add(BuildContext context) async {
    if (state.formBusy) return;
    final l = AppLocalizations.of(context)!;
    final input = GeoDataInput(
      fileName: name.text,
      type: state.type,
      url: url.text,
    );
    emit(state.copyWith(formBusy: true, clearFormError: true));
    try {
      final validation = await GeoDataValidator.validate(
        input.fileName.trim(),
        input.url.trim(),
      );
      if (!isPageActive) return;
      if (!validation.item1) {
        emit(state.copyWith(formError: validation.item2));
        return;
      }
      await service.add(input);
      if (!isPageActive) return;
      name.clear();
      url.clear();
      emit(state.copyWith(adding: false));
      if (context.mounted) _message(context, l.prototypeGeodataAdded);
    } catch (_) {
      emit(state.copyWith(formError: l.prototypeCheckNetwork));
    } finally {
      emit(state.copyWith(formBusy: false));
    }
  }

  Future<void> update(BuildContext context, PublishedGeoData? file) async {
    final key = file == null || file.builtIn ? -1 : file.row.id;
    if (state.fileBusy(key)) return;
    final l = AppLocalizations.of(context)!;
    final errors = {...state.errors}..remove(key);
    emit(state.copyWith(updating: {...state.updating, key}, errors: errors));
    try {
      if (file == null || file.builtIn) {
        await service.updateDefaults();
      } else {
        await service.updateCustom(file.row);
      }
      if (context.mounted) _message(context, l.prototypeGeodataUpdated);
    } catch (_) {
      emit(
        state.copyWith(errors: {...state.errors, key: l.prototypeCheckNetwork}),
      );
    } finally {
      final updating = {...state.updating}..remove(key);
      emit(state.copyWith(updating: updating));
    }
  }

  Future<void> updateAll(BuildContext context) async {
    if (!state.canUpdateAll) return;
    final l = AppLocalizations.of(context)!;
    final targets = state.custom;
    final errors = <int, String>{};
    emit(state.copyWith(updatingAll: true, errors: const {}));
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
      emit(state.copyWith(updatingAll: false, errors: errors));
    }
  }

  Future<void> delete(BuildContext context, PublishedGeoData file) async {
    if (state.fileBusy(file.row.id) || file.builtIn) return;
    final l = AppLocalizations.of(context)!;
    emit(state.copyWith(deleting: {...state.deleting, file.row.id}));
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
      if (confirmed != true || !isPageActive) return;
      final errors = {...state.errors}..remove(file.row.id);
      emit(state.copyWith(errors: errors));
      await service.deleteGeoDat(file.row);
    } catch (_) {
      emit(
        state.copyWith(
          errors: {...state.errors, file.row.id: l.prototypeCheckNetwork},
        ),
      );
    } finally {
      final deleting = {...state.deleting}..remove(file.row.id);
      emit(state.copyWith(deleting: deleting));
    }
  }

  static void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Future<void> disposePageResources() async {
    await _subscription?.cancel();
    name.dispose();
    url.dispose();
  }
}

@immutable
class GeoDataFilePageState {
  const GeoDataFilePageState({
    this.file,
    this.query = '',
    this.loading = true,
    this.failed = false,
  });

  final PublishedGeoData? file;
  final String query;
  final bool loading;
  final bool failed;

  List<XrayGeoListCodes> get codes {
    final normalizedQuery = query.trim().toLowerCase();
    return List.unmodifiable(
      (file?.index.codes ?? const <XrayGeoListCodes>[]).where(
        (entry) => entry.code!.toLowerCase().contains(normalizedQuery),
      ),
    );
  }

  GeoDataFilePageState copyWith({
    PublishedGeoData? file,
    bool clearFile = false,
    String? query,
    bool? loading,
    bool? failed,
  }) => GeoDataFilePageState(
    file: clearFile ? null : file ?? this.file,
    query: query ?? this.query,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
  );
}

class GeoDataFileController extends PageCubit<GeoDataFilePageState> {
  GeoDataFileController(this.fileId, {GeoDataService? service})
    : service = service ?? GeoDataService(),
      super(const GeoDataFilePageState());

  final int fileId;
  final GeoDataService service;
  StreamSubscription<List<PublishedGeoData>>? _subscription;

  void searchChanged(String value) => emit(state.copyWith(query: value));

  void initialize() {
    emit(state.copyWith(loading: true, failed: false));
    _subscription = service.watchPublished().listen((files) {
      final file = files.where((item) => item.row.id == fileId).firstOrNull;
      emit(
        state.copyWith(
          file: file,
          clearFile: file == null,
          loading: false,
          failed: false,
        ),
      );
    }, onError: (_) => emit(state.copyWith(loading: false, failed: true)));
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
  Future<void> disposePageResources() async {
    await _subscription?.cancel();
  }
}
