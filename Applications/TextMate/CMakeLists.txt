add_executable(TextMate MACOSX_BUNDLE)
file(GLOB _src src/*.cc src/*.mm)
target_sources(TextMate PRIVATE ${_src})

# Internal framework dependencies
target_link_libraries(TextMate PRIVATE
  BundleEditor BundleMenu BundlesManager CommitWindow CrashReporter DocumentWindow
  Find HTMLOutputWindow MenuBuilder OakAppKit OakCommand OakFilterList OakFoundation
  OakSystem OakTextView Preferences SoftwareUpdate authorization bundles cf command
  crash document io kvdb license network ns plist regexp scm settings text theme
  ${TEXTMATE_DEBUG_LIBS}
)

target_link_libraries(TextMate PRIVATE "-framework Cocoa")

# network headers need special handling — can't use <network/...> include
# path because it shadows Apple's Network.framework on case-insensitive macOS
target_include_directories(TextMate PRIVATE
  "${CMAKE_SOURCE_DIR}/Frameworks/network/src")

# Info.plist variable expansion
set(TARGET_NAME "TextMate")
set(APP_MIN_OS "${CMAKE_OSX_DEPLOYMENT_TARGET}")
set(APP_VERSION "${TEXTMATE_VERSION}")
string(TIMESTAMP YEAR "%Y")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CS_GET_TASK_ALLOW "true")
else()
  set(CS_GET_TASK_ALLOW "false")
endif()
configure_file(Info.plist ${CMAKE_CURRENT_BINARY_DIR}/Info.plist)

# Expand ${YEAR} in InfoPlist.strings — overwrite source copy in bundle
configure_file(
  resources/English.lproj/InfoPlist.strings
  ${CMAKE_CURRENT_BINARY_DIR}/English.lproj/InfoPlist.strings)
add_custom_command(TARGET TextMate POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy
    "${CMAKE_CURRENT_BINARY_DIR}/English.lproj/InfoPlist.strings"
    "$<TARGET_BUNDLE_DIR:TextMate>/Contents/Resources/English.lproj/InfoPlist.strings")
set_target_properties(TextMate PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist")

# Icon and image resources
file(GLOB _icons icons/*.icns)
file(GLOB _resources resources/*)
set(_all_resources ${_icons} ${_resources})
target_sources(TextMate PRIVATE ${_all_resources})
set_source_files_properties(${_all_resources} PROPERTIES
  MACOSX_PACKAGE_LOCATION Resources)

# Markdown → HTML for About window (uses existing bin/gen_html Ruby script)
file(GLOB _about_md about/*.md)
foreach(_md ${_about_md})
  get_filename_component(_name "${_md}" NAME_WE)
  set(_html "${CMAKE_CURRENT_BINARY_DIR}/${_name}.html")
  add_custom_command(
    OUTPUT "${_html}"
    COMMAND "${CMAKE_SOURCE_DIR}/bin/gen_html"
      -h "${CMAKE_CURRENT_SOURCE_DIR}/templates/header.html"
      -f "${CMAKE_CURRENT_SOURCE_DIR}/templates/footer.html"
      "${_md}" > "${_html}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    DEPENDS "${_md}" "${CMAKE_SOURCE_DIR}/bin/gen_html"
    COMMENT "gen_html: ${_name}.md")
  target_sources(TextMate PRIVATE "${_html}")
  set_source_files_properties("${_html}" PROPERTIES
    MACOSX_PACKAGE_LOCATION "Resources/About")
endforeach()

# Embedded CLI tools
textmate_embed(TextMate mate "MacOS")
textmate_embed(TextMate tm_query "MacOS")
textmate_embed(TextMate PrivilegedTool "Resources")

# Embedded plugins (.tmplugin bundles from submodules)
textmate_embed(TextMate Dialog "PlugIns" DIRECTORY)
textmate_embed(TextMate Dialog2 "PlugIns" DIRECTORY)

# Embedded QuickLook plugin
textmate_embed(TextMate TextMateQL "Library/QuickLook" DIRECTORY)

# Entitlements + code signing
configure_file(Entitlements.plist ${CMAKE_CURRENT_BINARY_DIR}/Entitlements.plist)
textmate_codesign(TextMate "${CS_IDENTITY}"
  ENTITLEMENTS "${CMAKE_CURRENT_BINARY_DIR}/Entitlements.plist")
