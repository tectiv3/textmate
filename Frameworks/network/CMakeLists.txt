# rave: require text cf io plist OakSystem regexp, libraries curl, frameworks SystemConfiguration Security
add_library(network STATIC)
file(GLOB _src src/*.cc src/*.mm)
target_sources(network PRIVATE ${_src})
# Can't use textmate_framework(network) — "network/" symlink shadows
# Apple's Network.framework on case-insensitive macOS. Use PRIVATE include
# only; consumers that need <network/...> must add the include explicitly.
set(_link "${CMAKE_CURRENT_BINARY_DIR}/include/network")
if(NOT EXISTS "${_link}")
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/include")
  file(CREATE_LINK
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${_link}"
    SYMBOLIC)
endif()
target_include_directories(network PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_include_directories(network PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/include")
target_link_libraries(network PUBLIC text cf io plist OakSystem regexp)
find_library(CURL_LIB curl REQUIRED)
target_link_libraries(network PRIVATE ${CURL_LIB}
  "-framework SystemConfiguration" "-framework Security")

# Tests disabled — <network/...> include collision with Apple Network.framework
