# rave: require cf io plist regexp scope text, sources src/*.{cc,rl}
add_library(settings STATIC)
file(GLOB _src src/*.cc)
target_sources(settings PRIVATE ${_src})
textmate_framework(settings)
target_link_libraries(settings PUBLIC cf io plist regexp scope text)

# Ragel
file(GLOB _rl_files src/*.rl)
foreach(_rl ${_rl_files})
  get_filename_component(_name "${_rl}" NAME)
  target_ragel_sources(settings "src/${_name}")
endforeach()

textmate_add_tests(settings)
