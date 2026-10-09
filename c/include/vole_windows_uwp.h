#ifndef VOLE_WINDOWS_UWP_H
#define VOLE_WINDOWS_UWP_H

#include "vole.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Only windows-uwp builds export this entry point. Windows package hosts use
 * a separate revision-3 JSON contract for package environment, VPN profile
 * lifecycle, immutable Session Snapshot publication, optional session backend
 * processes, and StartupTask operations. The startVpn/getVpnStatus/stopVpn
 * payloads accept an optional profileName (default: Vole); callers must use
 * the same name for all three operations. The response has the same allocation
 * ownership as VoleInvoke and must be released with VoleFree. The calling
 * thread must either have no COM apartment initialized or already be
 * initialized as MTA; STA and ASTA callers are unsupported. Each call balances
 * its own COM initialization. The library retains one process-lifetime MTA
 * reference for cached WinRT factories, so callers need not retain an MTA
 * between requests and may use different short-lived threads serially. A
 * previously uninitialized thread may belong to the implicit MTA on return;
 * no per-call explicit initialization is left on the calling thread.
 */
#ifdef _WIN32
char *VoleWindowsVpnInvoke(const char *request_json);
#endif

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* VOLE_WINDOWS_UWP_H */
