set(APP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/app")

install(CODE "file(REMOVE_RECURSE \"${CMAKE_INSTALL_PREFIX}/bin\")"
        COMPONENT Runtime)

install(FILES "${APP_DIR}/libXray.dll"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)

install(PROGRAMS
        "${APP_DIR}/OneXrayCore.exe"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)

set(VCORE_DLL "${APP_DIR}/vcore.dll")
set(VCORE_VPN_HOST "${APP_DIR}/vcore-windows-vpn-host.exe")
set(VCORE_SESSION_HOST "${APP_DIR}/vcore-windows-session-host.exe")
if(EXISTS "${VCORE_DLL}" AND EXISTS "${VCORE_VPN_HOST}" AND
   EXISTS "${VCORE_SESSION_HOST}")
    install(FILES "${VCORE_DLL}"
            DESTINATION "${CMAKE_INSTALL_PREFIX}"
            COMPONENT Runtime)
    install(PROGRAMS "${VCORE_VPN_HOST}" "${VCORE_SESSION_HOST}"
            DESTINATION "${CMAKE_INSTALL_PREFIX}"
            COMPONENT Runtime)
endif()
