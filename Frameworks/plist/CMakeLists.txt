# rave: require text cf io, sources src/*.{cc,rl,capnp}, libraries capnp kj
add_library(plist STATIC)
file(GLOB _src src/*.cc)
target_sources(plist PRIVATE ${_src})
textmate_framework(plist)
target_link_libraries(plist PUBLIC text cf io "-framework CoreFoundation")

# Ragel sources
target_ragel_sources(plist src/ascii.rl)

# Cap'n Proto
capnp_generate_cpp(CAPNP_SRCS CAPNP_HDRS "${CMAKE_CURRENT_SOURCE_DIR}/src/cache.capnp")
target_sources(plist PRIVATE ${CAPNP_SRCS} ${CAPNP_HDRS})
target_link_libraries(plist PRIVATE CapnProto::capnp)

textmate_add_tests(plist)
