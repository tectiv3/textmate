# rave: require text cf io plist OakSystem regexp, libraries curl, frameworks SystemConfiguration Security
add_library(network STATIC)
file(GLOB _src src/*.cc src/*.mm)
target_sources(network PRIVATE ${_src})
# Can't use textmate_framework(network) — "network/" symlink shadows
# Apple's Network.framework on case-insensitive macOS (WebKit includes
# <Network/Network.h> which resolves to our headers). Expose src/ directly
# so consumers include e.g. <constants.h> instead of <network/constants.h>.
target_include_directories(network PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_link_libraries(network PUBLIC text cf io plist OakSystem regexp)
find_library(CURL_LIB curl REQUIRED)
target_link_libraries(network PRIVATE ${CURL_LIB}
  "-framework SystemConfiguration" "-framework Security")

# Tests disabled — <network/...> include collision with Apple Network.framework
