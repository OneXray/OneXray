install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/app/libXray.dll"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)

set(APP_BIN_DIR "${CMAKE_INSTALL_PREFIX}/bin")

install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/app/OneXrayCore.exe"
        DESTINATION "${APP_BIN_DIR}")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/app/wintun.dll"
        DESTINATION "${APP_BIN_DIR}"
        COMPONENT Runtime)
