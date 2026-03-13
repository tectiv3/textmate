# rave: require OakAppKit, frameworks Cocoa WebKit
add_library(SoftwareUpdate STATIC)
file(GLOB _src src/*.mm)
target_sources(SoftwareUpdate PRIVATE ${_src})
textmate_framework(SoftwareUpdate)
target_link_libraries(SoftwareUpdate PUBLIC OakAppKit "-framework Cocoa" "-framework WebKit")

textmate_add_tests(SoftwareUpdate)
