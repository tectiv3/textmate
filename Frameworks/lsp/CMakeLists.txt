add_library(lsp STATIC)
file(GLOB _src src/*.mm src/*.cc)
target_sources(lsp PRIVATE ${_src})
textmate_framework(lsp)
target_link_libraries(lsp PUBLIC
  document settings text ns "-framework Cocoa")
target_include_directories(lsp PRIVATE "${CMAKE_SOURCE_DIR}/vendor")
