set(APP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/app")

install(CODE "file(REMOVE_RECURSE \"${CMAKE_INSTALL_PREFIX}/bin\")"
        COMPONENT Runtime)

# Both distribution modes use the same flat runtime layout. Missing native
# dependencies must fail the build instead of producing an incomplete package.
install(FILES
        "${APP_DIR}/libXray.dll"
        "${APP_DIR}/wintun.dll"
        "${APP_DIR}/vcore.dll"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)

install(PROGRAMS
        "${APP_DIR}/OneXrayCore.exe"
        "${APP_DIR}/vcore-windows-vpn-host.exe"
        "${APP_DIR}/vcore-windows-session-host.exe"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)
