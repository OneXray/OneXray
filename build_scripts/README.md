# Build and release

This is the authoritative packaging and release guide. For local Flutter Debug,
start with [FIRST_RUN](../readme/FIRST_RUN.md). Runtime behavior belongs in
[App](../docs/app.md), verification boundaries in
[Validation](../docs/validation.md), and bridge/API contracts in
[External interfaces](../docs/external-interfaces.md).

## Prepare the workspace

Keep `OneXray/` and `libXray/` as sibling checkouts; Windows also needs `VCore/`
alongside them, or an explicit `VCORE_DIR`. Outputs go to sibling `output/`.
The scripts use the checked-out dependency commits. Xray-core is resolved by
libXray's Go module, not a separate Xray-core checkout.

Install Python 3.12+, `uv`, Flutter/Dart and Go on `PATH`. Platform requirements:

| Target | Host and packaging tools |
| --- | --- |
| Apple | macOS, Xcode, Fastlane and signing credentials. Projects use SwiftPM; the current deployment helper still runs legacy `pod repo update`, so this entry point also requires CocoaPods. Local Debug does not need it. |
| Android | Android SDK/NDK, a JDK compatible with the Gradle wrapper, Fastlane and Play signing/upload credentials. Consult the Gradle files and workflow rather than copying tool versions here. |
| Windows | Native x64/ARM64 Windows, Visual Studio C++ tools, Windows SDK, Rust, LLVM/libclang and matching Go/C compiler tools. EXE/ZIP require Fastforge; EXE also needs Inno Setup (`INNO_SETUP_PATH` can select its directory). MSIX uses `makeappx`/`signtool`. |
| Linux | Native Linux toolchain and GTK/plugin dependencies; Fastforge for ZIP/DEB. |

From the App root, prepare the Python environment; activate Fastforge only for
Linux or Windows EXE/ZIP:

```shell
uv sync --project build_scripts
dart pub global activate fastforge
```

The [Build workflow](../.github/workflows/build.yml), [Gradle configuration](../android/app/build.gradle.kts),
and [script configuration](app/config.py) are the toolchain/version sources of
truth. Keep `LIBXRAY_REF` at `main` unless explicitly instructed otherwise.
Run Flutter/Dart commands serially, including across terminals.

## Run a build safely

Use a clean or disposable checkout and a separate output directory from prior
builds. These commands are not general-purpose local validation:

- Apple/Android targets call Fastlane deployment lanes and can upload to stores;
  `macos_se` signs and notarizes externally. Confirm the target and credentials.
- Builds update `pubspec.yaml`, native libraries, bundled Geodata and platform
  files. Apple also updates project build numbers.
- `macos_se` replaces the local `macos/` tree with `macos_se/`; preserve local
  changes before running it.
- Android replaces `##version_code##` in `android/fastlane/Fastfile` without
  restoring it. Start each build from a clean copy.
- [setup_flutter.sh](setup_flutter.sh) deletes and recreates
  `ONEXRAY_FLUTTER_ROOT` (default `$HOME/flutter/stable`). Use a disposable SDK
  location, not a checkout you need to keep.

Set a positive `BUILD_NUMBER`; the script adds the base from `app/config.py`.
Run from the OneXray root, replacing `<system>` with a target below:

```shell
export BUILD_NUMBER=1
uv run --project build_scripts python build_scripts/main.py OneXray <system>
```

```powershell
$env:BUILD_NUMBER = "1"
uv run --project build_scripts python build_scripts/main.py OneXray <system>
```

| `system` | Result / external action |
| --- | --- |
| `ios` | IPA and TestFlight upload. |
| `macos` | Mac App Store package and App Store Connect upload. |
| `macos_se` | Developer ID signed, notarized universal ZIP. |
| `android` | Play internal draft AAB upload and universal APK download. |
| `windows` | EXE + ZIP; `--windows-mode msix` selects Store MSIX. |
| `linux` | ZIP + DEB for the host architecture. |

The entry point's `--help` documents CLI syntax. Native/Geodata copying and FFI
generation are part of this build; they do not replace device/channel acceptance.

## Windows

`--windows-mode exe|msix` sets both packaging and
`--dart-define=ONEXRAY_WINDOWS_MODE`. The default is `exe`; it is not a saved user
preference and does not fall back based on package identity.

| Mode | Runtime / startup | Distribution |
| --- | --- | --- |
| `exe` | Native TUN/Wintun; UAC only for standalone Core operations; current-user Startup shortcut. | EXE installer + ZIP. |
| `msix` | VCore system VPN; Session Host supervises ordinary-permission Core over private loopback SOCKS; packaged `VCoreStartup`. | Microsoft Store MSIX. |

Both modes require an Xray outbound interface. EXE/ZIP share a data location;
MSIX has separate package data and is not an interchangeable upgrade channel.
MSIX policy controls do not apply to EXE. See [App](../docs/app.md) for runtime
and data ownership.

Architecture defaults to the host; `ONEXRAY_WINDOWS_ARCH=x64|arm64` requires
matching Flutter, Go, Rust and MSVC toolchains. The builder prepares libXray,
VCore, Wintun and Geodata before packaging. CMake installs the App, Core, Wintun,
three VCore files and target MSVC runtime DLLs together in a flat layout.
ZIP users must extract the entire bundle. Do not copy DLLs from System32 or
assume a global VC++ runtime is installed; Windows supplies the system UCRT.

VCore copying verifies its artifact manifest, integration revision, exact file
set, SHA-256 and PE architecture; it does not require `buildIdentity`.
Wintun comes from the hash-verified official archive cached under workspace
`references/windows-build/`. Accepted artifacts and checks are defined in
[windows.py](app/windows.py) and [app.cmake](../windows/app.cmake).

### EXE and ZIP

One Fastforge invocation builds and packages both formats from the same EXE-mode
Release bundle. The builder temporarily adjusts installer architecture and
numeric marketing version, then restores the packaging configuration and
build-number-bearing pubspec even on failure. It collects only the expected
current packages; see [installer sources](../windows/packaging/exe/).

Preserve the released installer AppId, user-level scope, `OneXray.exe` entry point,
shortcuts and `onexray:` registration. ZIP does not register shortcuts/protocols.
Uninstall removes only registrations pointing to this installation; it preserves
user data and does not stop another installation's Core. Stop VPN and exit before
installing, upgrading or uninstalling.

### MSIX and development signing

Build MSIX separately; do not reuse EXE-mode binaries. The script augments the
base `msix:create` package with VCore extensions/activation, required capabilities
and disabled startup task, then repacks it. Bare `dart run msix:create` is not an
equivalent package. Run MSIX as an installed App with package identity, not a bare
EXE; Core must not require UAC. Details live in
[windows_msix.py](app/windows_msix.py) and [pubspec.yaml](../pubspec.yaml).

For a local development package, use a Code Signing certificate with its private
key and a matching publisher. Import a PFX into the current user's `My` store:

```powershell
$password = Read-Host "PFX password" -AsSecureString
$certificate = Import-PfxCertificate -FilePath "C:\path\development.pfx" `
    -Password $password -CertStoreLocation "Cert:\CurrentUser\My"
$env:ONEXRAY_DEV_SIGN = "1"
$env:ONEXRAY_DEV_CERT_THUMBPRINT = $certificate.Thumbprint
$env:ONEXRAY_DEV_PUBLISHER = $certificate.Subject
uv run --project build_scripts python build_scripts/main.py OneXray windows --windows-mode msix
```

Set `BUILD_NUMBER` as above. Trust a self-signed public CER only on the test machine
in `Cert:\CurrentUser\Root` and `Cert:\LocalMachine\TrustedPeople` (the latter
requires administrator PowerShell). The builder uses identity `OneXray.Dev`,
signs and verifies the package; it does not create/import/delete certificates.
CI may instead provide `ONEXRAY_DEV_CERT_PATH` and `ONEXRAY_DEV_CERT_PASSWORD`.
Incompatible development packages require a clean test install; released-package
upgrade/data-preservation acceptance remains a separate check.

## Provenance and publishing

`Build` resolves dependency refs once and checks out those full SHAs in every
platform job. A local dependency commit is not available to CI until published
to its configured repository. Receipts record App/dependency commits, source and
effective versions, initial source dirtiness, run/attempt, actual tool versions,
lock/native/Geodata hashes and package SHA-256. Windows receipts additionally
record mode so EXE cannot satisfy MSIX requirements.

[verify_release.py](verify_release.py) requires matching successful Build
metadata, clean recorded sources, receipts and package hashes; the release tag
must resolve to the built App commit. Manual builds have no metadata exemption.
On retry, rerun metadata and platform jobs together, not across run attempts.

- [Publish](../.github/workflows/publish.yml) creates/updates a GitHub pre-release
  and replaces only the verified asset list. `target.txt` scopes single-platform
  publishing; `all` requires every GitHub target. Windows needs both architectures'
  EXE/ZIP, Linux both architectures' ZIP/DEB. MAS PKG and Play AAB are not GitHub
  assets; macOS publishes the SE ZIP. Promote to stable separately.
- [Microsoft Store](../.github/workflows/publish-microsoft-store.yml) accepts a
  successful Build run's two MSIX-mode receipts/packages and emits an MSIX Bundle
  artifact. It does not upload to the Store; submit manually in Partner Center.
- Tool versions and provenance are evidence, not installed-package/VPN acceptance.
  Windows changes need x64/ARM64 × EXE/MSIX builds, a loadable Core, correct
  manifest/payload, and clean-machine install/upgrade/UAC/lifecycle checks. Record
  untested platforms; see [Validation](../docs/validation.md).

### WinGet

[Update winget](../.github/workflows/update-winget.yml) runs after a stable Release
or manual selection of an existing tag. It skips pre-releases, rejects drafts,
and requires published x64/ARM64 EXE assets, not ZIP/MSIX or Build artifacts.
The identifier is `YuanDevLLC.OneXray`.

The workflow generates with Komac `update --dry-run --output`, fixes user scope,
install directory and display name through [winget_manifest.py](winget_manifest.py),
then validates schema, effective installer fields, release URLs and hashes.
The helper uses `uv run --script build_scripts/winget_manifest.py` from the App
root; its inline dependencies are separate from the standard-library build scripts.
Generation/validation use read-only credentials. Only the final `komac submit`
opens an external PR; it needs `PACKAGE_MANAGER_GITHUB_TOKEN` with `public_repo`
and write access to the repository owner's `winget-pkgs` fork. Existing open PRs
for that version block duplicate submission; nothing auto-merges or deletes
historical versions.

For local validation use `komac submit <manifest-directory> --dry-run`, never an
actual submission. Keep installer fields aligned with the released EXE. Old
packages without bundled CRT need architecture-specific VC++ dependencies;
verified new packages with bundled CRT should not inherit them. Binary fixes use
a new release, not replacement of published installers/digests. Manifest checks
do not substitute for Windows installation acceptance.
