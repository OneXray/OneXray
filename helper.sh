# !/bin/bash

dart run build_runner build --delete-conflicting-outputs
dart run pigeon --input pigeon/message.dart
dart run ffigen
flutter pub upgrade --major-versions
flutter pub upgrade --tighten

sudo setcap cap_net_admin+epi OneXrayCore
