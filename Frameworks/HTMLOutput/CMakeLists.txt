add_library(HTMLOutput STATIC)
file(GLOB_RECURSE _src src/*.mm)
target_sources(HTMLOutput PRIVATE ${_src})
textmate_framework(HTMLOutput)
target_link_libraries(HTMLOutput PUBLIC
  OakAppKit OakFoundation cf document io ns text "-framework Cocoa" "-framework WebKit")

textmate_add_tests(HTMLOutput)
