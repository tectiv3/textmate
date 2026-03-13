# rave: require crash text cf ns OakAppKit OakFoundation, frameworks Security
# Special: -Wl,-U,__Z15revoked_serialsv (weak undefined symbol)
add_library(license STATIC)
file(GLOB _src src/*.cc src/*.mm)
target_sources(license PRIVATE ${_src})
textmate_framework(license)
target_link_libraries(license PUBLIC crash text cf ns OakAppKit OakFoundation
  "-framework Security")
target_link_options(license PUBLIC "-Wl,-U,__Z15revoked_serialsv")
