# rave: sources src/*.{mm,capnp}, libraries capnp kj
add_library(encoding STATIC)
file(GLOB _src src/*.mm)
target_sources(encoding PRIVATE ${_src})
textmate_framework(encoding)
target_include_directories(encoding PRIVATE
  "${CMAKE_CURRENT_BINARY_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}/src")

capnp_generate_cpp(CAPNP_SRCS CAPNP_HDRS "${CMAKE_CURRENT_SOURCE_DIR}/src/frequencies.capnp")
target_sources(encoding PRIVATE ${CAPNP_SRCS} ${CAPNP_HDRS})
target_link_libraries(encoding PRIVATE CapnProto::capnp)
