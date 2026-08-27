set(APP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/app")

target_link_libraries(${BINARY_NAME} PRIVATE
        "${APP_DIR}/libXray.so"
)
install(FILES "${APP_DIR}/libXray.so"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)

install(PROGRAMS
        "${APP_DIR}/OneXrayCore"
        DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)
