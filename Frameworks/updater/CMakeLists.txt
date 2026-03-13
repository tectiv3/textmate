# rave: require text io network plist
add_library(updater STATIC)
file(GLOB _src src/*.cc)
target_sources(updater PRIVATE ${_src})
textmate_framework(updater)
target_link_libraries(updater PUBLIC text io network plist)
