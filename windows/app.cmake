set(APP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/app")
set(APP_BIN_DIR "${CMAKE_INSTALL_PREFIX}/bin")

install(FILES "${APP_DIR}/libXray.dll"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)

install(PROGRAMS
        "${APP_DIR}/OneXrayCore.exe"
        DESTINATION "${APP_BIN_DIR}"
        COMPONENT Runtime)

install(CODE "file(REMOVE \"${APP_BIN_DIR}/wintun.dll\")"
        COMPONENT Runtime)
