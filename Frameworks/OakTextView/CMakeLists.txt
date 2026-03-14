add_library(OakTextView STATIC)
file(GLOB _src src/*.cc src/*.mm)
target_sources(OakTextView PRIVATE ${_src})
textmate_framework(OakTextView)
target_link_libraries(OakTextView PUBLIC
  BundleMenu BundlesManager Find HTMLOutput MenuBuilder OakAppKit OakCommand
  OakFilterList OakFoundation OakSystem Preferences buffer bundles cf command
  crash document editor file io layout ns settings text theme
  "-framework Cocoa")
target_include_directories(OakTextView PRIVATE "${CMAKE_SOURCE_DIR}/vendor")
