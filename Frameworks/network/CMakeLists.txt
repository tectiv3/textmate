# rave: require text cf io plist OakSystem regexp, libraries curl, frameworks SystemConfiguration Security
add_library(network STATIC)
file(GLOB _src src/*.cc)
target_sources(network PRIVATE ${_src})
textmate_framework(network)
target_link_libraries(network PUBLIC text cf io plist OakSystem regexp)
find_library(CURL_LIB curl REQUIRED)
target_link_libraries(network PRIVATE ${CURL_LIB}
  "-framework SystemConfiguration" "-framework Security")

textmate_add_tests(network)
