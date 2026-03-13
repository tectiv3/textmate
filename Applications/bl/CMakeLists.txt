# rave: require OakSystem io regexp text updater
add_executable(bl)
file(GLOB _src src/*.cc)
target_sources(bl PRIVATE ${_src})
target_link_libraries(bl PRIVATE OakSystem io regexp text updater)
