# XPC service bundle
add_executable(SyntaxMate)
file(GLOB _src src/*.mm)
target_sources(SyntaxMate PRIVATE ${_src})
target_link_libraries(SyntaxMate PRIVATE file theme OakDebug)

set_target_properties(SyntaxMate PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/SyntaxMate.xpc/Contents/MacOS")
