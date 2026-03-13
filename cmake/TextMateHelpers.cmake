# cmake/TextMateHelpers.cmake
# Custom build functions for TextMate's CMake build system.

# Framework include path setup.
# Source tree uses flat layout (src/buffer.h) but consumers
# include <buffer/buffer.h>. Symlink: build/include/<target>/ → src/
function(textmate_framework TARGET)
  set(_link "${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET}")
  if(NOT EXISTS "${_link}")
    file(CREATE_LINK
      "${CMAKE_CURRENT_SOURCE_DIR}/src"
      "${_link}"
      SYMBOLIC)
  endif()
  target_include_directories(${TARGET} PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/include")
endfunction()

# Ragel state machine compilation (.rl → .cc or .mm)
function(target_ragel_sources TARGET)
  foreach(_rl ${ARGN})
    get_filename_component(_name "${_rl}" NAME)
    string(REGEX REPLACE "\\.rl$" "" _out_name "${_name}")
    if(NOT _out_name MATCHES "\\.(cc|mm)$")
      set(_out_name "${_out_name}.cc")
    endif()
    set(_out "${CMAKE_CURRENT_BINARY_DIR}/${_out_name}")
    add_custom_command(
      OUTPUT "${_out}"
      COMMAND "${RAGEL_EXECUTABLE}" -o "${_out}" "${CMAKE_CURRENT_SOURCE_DIR}/${_rl}"
      DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${_rl}"
      COMMENT "Ragel: ${_rl}")
    target_sources(${TARGET} PRIVATE "${_out}")
  endforeach()
endfunction()

# Xib compilation (.xib → .nib via ibtool)
function(target_xib_sources TARGET RESOURCE_LOCATION)
  foreach(_xib ${ARGN})
    get_filename_component(_name "${_xib}" NAME_WE)
    set(_nib "${CMAKE_CURRENT_BINARY_DIR}/${_name}.nib")
    add_custom_command(
      OUTPUT "${_nib}"
      COMMAND xcrun ibtool --compile "${_nib}"
        --errors --warnings --notices
        --output-format human-readable-text
        "${CMAKE_CURRENT_SOURCE_DIR}/${_xib}"
      DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${_xib}"
      COMMENT "Xib: ${_xib}")
    target_sources(${TARGET} PRIVATE "${_nib}")
    set_source_files_properties("${_nib}" PROPERTIES
      MACOSX_PACKAGE_LOCATION "Resources/${RESOURCE_LOCATION}")
  endforeach()
endfunction()

# Asset catalog compilation (.xcassets → .car via actool)
function(target_asset_catalog TARGET XCASSETS_DIR)
  file(GLOB_RECURSE _assets "${CMAKE_CURRENT_SOURCE_DIR}/${XCASSETS_DIR}/*")
  set(_car "${CMAKE_CURRENT_BINARY_DIR}/Assets.car")
  add_custom_command(
    OUTPUT "${_car}"
    COMMAND xcrun actool --compile "${CMAKE_CURRENT_BINARY_DIR}"
      --errors --warnings --notices
      --output-format human-readable-text
      --minimum-deployment-target=${CMAKE_OSX_DEPLOYMENT_TARGET}
      --platform=macosx
      "${CMAKE_CURRENT_SOURCE_DIR}/${XCASSETS_DIR}"
    DEPENDS ${_assets}
    COMMENT "AssetCatalog: ${XCASSETS_DIR}")
  target_sources(${TARGET} PRIVATE "${_car}")
  set_source_files_properties("${_car}" PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources)
endfunction()

# Code signing with optional entitlements
function(textmate_codesign TARGET IDENTITY)
  cmake_parse_arguments(_CS "" "ENTITLEMENTS" "" ${ARGN})
  set(_flags --force --options runtime)
  if(CMAKE_BUILD_TYPE STREQUAL "Release")
    list(APPEND _flags --timestamp)
  else()
    list(APPEND _flags --timestamp=none)
  endif()
  if(_CS_ENTITLEMENTS)
    list(APPEND _flags --entitlements "${_CS_ENTITLEMENTS}")
  endif()
  add_custom_command(TARGET ${TARGET} POST_BUILD
    COMMAND xcrun codesign --sign "${IDENTITY}" ${_flags}
      "$<TARGET_BUNDLE_DIR:${TARGET}>"
    COMMENT "Codesign: ${TARGET}")
endfunction()

# Embed a target into an app bundle.
# Usage: textmate_embed(AppTarget DepTarget "Location/In/Bundle" [DIRECTORY])
# Without DIRECTORY: copies the single executable file.
# With DIRECTORY: copies the entire bundle directory.
function(textmate_embed APP_TARGET DEP_TARGET LOCATION)
  cmake_parse_arguments(_EMB "DIRECTORY" "" "" ${ARGN})
  add_dependencies(${APP_TARGET} ${DEP_TARGET})
  if(_EMB_DIRECTORY)
    add_custom_command(TARGET ${APP_TARGET} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        "$<TARGET_BUNDLE_DIR:${DEP_TARGET}>"
        "$<TARGET_BUNDLE_DIR:${APP_TARGET}>/Contents/${LOCATION}")
  else()
    add_custom_command(TARGET ${APP_TARGET} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy
        "$<TARGET_FILE:${DEP_TARGET}>"
        "$<TARGET_BUNDLE_DIR:${APP_TARGET}>/Contents/${LOCATION}/$<TARGET_FILE_NAME:${DEP_TARGET}>")
  endif()
endfunction()

# Test generation using bin/gen_test (Ruby script that generates runners
# from void test_*() and void benchmark_*() signatures)
function(textmate_add_tests FRAMEWORK_TARGET)
  file(GLOB _test_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/tests/t_*.cc"
    "${CMAKE_CURRENT_SOURCE_DIR}/tests/t_*.mm")
  if(NOT _test_sources)
    return()
  endif()

  set(_test_target "${FRAMEWORK_TARGET}_tests")
  set(_runner "${CMAKE_CURRENT_BINARY_DIR}/test_runner.cc")

  add_custom_command(
    OUTPUT "${_runner}"
    COMMAND "${CMAKE_SOURCE_DIR}/bin/gen_test" ${_test_sources} > "${_runner}"
    DEPENDS ${_test_sources} "${CMAKE_SOURCE_DIR}/bin/gen_test"
    COMMENT "gen_test: ${FRAMEWORK_TARGET}")

  add_executable(${_test_target} "${_runner}" ${_test_sources})
  target_link_libraries(${_test_target} PRIVATE ${FRAMEWORK_TARGET} ${TEXTMATE_DEBUG_LIBS})
  target_include_directories(${_test_target} PRIVATE "${CMAKE_SOURCE_DIR}/Shared/include")
  add_test(NAME ${FRAMEWORK_TARGET} COMMAND ${_test_target})
endfunction()
