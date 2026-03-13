# rave: require text io network plist
add_library(updater STATIC)
file(GLOB _src src/*.cc)
target_sources(updater PRIVATE ${_src})
textmate_framework(updater)
target_link_libraries(updater PUBLIC text io network plist)
# Need <network/...> includes (not propagated publicly to avoid macOS collision)
target_include_directories(updater PRIVATE
  "${CMAKE_BINARY_DIR}/Frameworks/network/include")
