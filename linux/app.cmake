target_link_libraries(${BINARY_NAME} PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/app/libXray.so"
)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/app/libXray.so"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)

set(APP_BIN_DIR "${CMAKE_INSTALL_PREFIX}/bin")

install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/app/OneXrayCore"
        DESTINATION "${APP_BIN_DIR}")
