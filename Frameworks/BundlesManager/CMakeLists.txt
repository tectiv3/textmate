add_library(BundlesManager STATIC)
file(GLOB _src src/*.cc src/*.mm)
target_sources(BundlesManager PRIVATE ${_src})
textmate_framework(BundlesManager)
target_link_libraries(BundlesManager PUBLIC
  OakAppKit OakFoundation SoftwareUpdate bundles io ns regexp text "-framework Foundation")
