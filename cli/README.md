# OneXray CLI (`onexray-cli`)

A thin Go client for the running desktop OneXray App's local HTTP API. The App
owns configuration parsing, compilation, Geodata access and libXray validation;
the CLI does not contain Xray-core or a second implementation of App rules.

## Connect once

1. Open the desktop App and enable **Local API** in its settings.
2. Copy its token, then run:

   ```sh
   onexray-cli auth login
   ```

3. Paste the token into the hidden terminal prompt. The default endpoint is
   `http://127.0.0.1:18587`; use `auth login --endpoint URL` if the App uses a
   different port. The CLI checks the API before saving credentials.

Token arguments, environment-variable tokens and noninteractive token input are
not supported. Do not paste tokens into AI conversations. After login, an AI can
invoke the CLI without seeing the token. Keep the App running (a hidden window
is fine); the CLI does not launch it or connect to the VPN process itself.

The current-user config directory contains `OneXrayCLI/credentials.json`:

- macOS: `~/Library/Application Support/OneXrayCLI/credentials.json`
- Linux: `$XDG_CONFIG_HOME/OneXrayCLI/credentials.json`, or
  `~/.config/OneXrayCLI/credentials.json`
- Windows: `%AppData%\OneXrayCLI\credentials.json`

Credentials are local plaintext protected by directory/file permissions
(`0700`/`0600` on Unix; a protected current-user-only DACL on Windows). They are
not encrypted and are not protected from another process running as the same
user. `onexray-cli auth logout` removes only the CLI credentials; reset the token in
the App to revoke it. Closing/reopening the App does not rotate its token.

The client accepts only `http://127.0.0.1:<port>`, bypasses proxy environment
variables, refuses redirects, and sends credentials in the Authorization header.
The API is not an Internet endpoint or a security sandbox.

## Inspect and validate

```sh
onexray-cli info --json
onexray-cli config validate --kind outbound --file node.json --json
onexray-cli config validate --kind routing --file routing.json --json
onexray-cli config validate --kind advanced-routing --file template.json --json
onexray-cli config validate --kind raw --file full-config.json --name Example --json
onexray-cli config validate --kind raw --file - --json < full-config.json
```

Kinds:

| Kind | Input |
| --- | --- |
| `outbound` | One outbound JSON object, not an `outbounds` wrapper. |
| `routing` | An ordinary custom-routing template with empty outbound slots. |
| `advanced-routing` | An advanced custom-routing template with empty slots. |
| `raw` | A complete Raw JSON configuration. |

The raw input text is preserved in the HTTP request so the App can report source
locations. `--name` supplies the configuration name where supported by the App.
Template validation uses the same placeholder nodes as App save validation; it
does not validate real nodes that were not supplied. Missing Geodata/certificate
files are errors, not a request to download files. Resources come from the
running App's local environment.

Validation constructs and closes the projected libXray instance without starting
VPN. It is not proof of future listener availability, permissions, node reachability
or successful VPN operation. Kernel construction can still have process-level
side effects; do not validate untrusted configurations expecting a sandbox.

## Compile a preview

```sh
onexray-cli config compile --kind routing --file routing.json \
  --outbounds nodes.json --options options.json --output preview.json --json
```

`nodes.json` is an array of actual outbound objects, with one per template slot.
Only `routing` and `advanced-routing` use `--outbounds`. For `outbound`, the input
itself is compiled using the all-VPN route; `raw` uses its own complete outbounds.
`--options` is required for every compilation and must contain explicit runtime
values, for example:

```json
{
  "platform": "macos",
  "sessionDirectory": "/absolute/path/to/preview-run",
  "metricsPort": 19001,
  "socksPort": 19002,
  "ipv6": true
}
```

`platform` supports `ios`, `macos`, `android`, `windows`, and `linux`. Windows also
requires `windowsMode` (`exe` or `msix`); Windows/Linux require `interfaceName`.
Optional options are `tunDnsIpv4Address`, `tunDnsIpv6Address`, `logEnabled`,
`logFilesSupported`, `logLevel`, `dnsLog`, and `maskAddress`; omitted values use
the App compiler's defaults. Compilation does not use the App's current connection
selection or silently look up real nodes from its database.

A `passed` result with `stage: compile` means a preview was generated, **not** that
kernel validation ran. Compilation never saves to the App, writes `start.json`,
downloads Geodata or starts VPN. `--output` writes only the requested new local
file with private permissions; it refuses to overwrite existing files. Without
it, the compiled JSON is printed. JSON output can contain node credentials and
other secrets: handle it as carefully as the input files.

## Automation contract

`--json` prints an API result (or a structured local failure), without progress
messages on stdout. Diagnostics carry `code`, `message` and optional
`path`/`offset`/`line`/`column`. Paths retain the App's array of property names and
integer indices, such as `["routing", "rules", 0, "sourceIP"]`. Missing positions
are not guessed. The original kernel message is retained by the App. API version
1 is required. A successful validation requires `stage: kernel` and
`validationConfig`; a successful compilation requires `stage: compile` and
`compiledConfig`. A mismatched or incomplete success response is a protocol error.

| Exit | Meaning |
| --- | --- |
| 0 | Requested operation passed; inspect `stage` to distinguish compile from kernel validation. |
| 1 | Configuration validation failed. |
| 2 | CLI usage, file or size error. |
| 3 | App unreachable or request timed out. |
| 4 | Missing/invalid credentials or authentication rejected. |
| 5 | Incompatible/malformed API response or forbidden redirect. |
| 6 | App did not run the operation (for example busy or not ready). |

Requests and responses are limited to 16 MiB. The request timeout is 125 seconds.
A timeout does not cancel a native operation that has already started inside the
App. There is no automatic retry, token refresh or background App startup.

## Build and package

Go 1.27.1 or newer and Python 3.12+ are sufficient; Dart, Flutter and native C
toolchains are not required. From the repository root:

```sh
cd cli
go test ./...
go build -o onexray-cli .
cd ..
python3 build_scripts/build_cli.py
# Or just the current Mac architecture:
python3 build_scripts/build_cli.py --target darwin-arm64
```

The packaging script reads the version from `pubspec.yaml`, sets `CGO_ENABLED=0`,
and produces `OneXrayCLI-<version>-<os>-<arch>.tar.gz` (macOS/Linux) or `.zip`
(Windows), plus `SHA256SUMS`, in the workspace's `output/cli/` directory. Targets
are `darwin`, `linux`, `windows`, each with `amd64` and `arm64`. Every archive
contains `onexray-cli`/`onexray-cli.exe`, this README and licenses. Sources, App artifacts,
credentials and installed applications are not modified.

The separate [CLI workflow](../.github/workflows/cli.yml) tests on macOS, Linux
and Windows and cross-compiles all six targets into downloadable workflow
artifacts. It does not upload to stores or attach files to GitHub Releases; the
existing App release provenance checks remain unchanged. Binaries are not
Developer ID signed/notarized or Authenticode signed; Gatekeeper or Windows
reputation prompts remain a distribution consideration. Native CI/test status
and locally cross-compiled files are different evidence, not interchangeable.

## Dependency maintenance review

Reviewed on 2026-09-22. Only Go-maintained `golang.org/x/term v0.46.0` and
`golang.org/x/sys v0.48.0` are added: hidden terminal input and Windows ACLs.
Both require Go 1.26+ and work without CGO; this module pins Go 1.27.1.

- [term](https://github.com/golang/term) is not archived; v0.46.0 was published
  2026-09-08. A [2026-08-27 input handling fix](https://github.com/golang/term/commit/7c2fb74aea627b563f897ce0ba62658826a024c8)
  was reviewed by Go maintainers and closed [issue 80661](https://github.com/golang/go/issues/80661).
- [sys](https://github.com/golang/sys) is not archived; v0.48.0 was published
  2026-08-31. [Active substantive changes](https://github.com/golang/sys/commit/01b91195d9aeaba1dab70b882a12f741f568a510)
  and maintainer reviews continued on 2026-09-18.
- Development uses Go's Gerrit and central issue tracker, so low GitHub PR
  activity alone is not an inactivity signal. The modules are pre-v1 APIs and
  raise their minimum Go version with the Go support policy; upgrades must
  retain the cross-platform terminal/ACL tests.
