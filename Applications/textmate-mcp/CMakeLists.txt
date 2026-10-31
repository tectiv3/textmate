add_executable(textmate-mcp src/main.mm)
target_link_libraries(textmate-mcp PRIVATE "-framework Foundation")
target_compile_definitions(textmate-mcp PRIVATE "TEXTMATE_VERSION=\"${TEXTMATE_VERSION}\"")
add_executable(tm-codex src/launcher.mm)
target_link_libraries(tm-codex PRIVATE "-framework Foundation")
add_executable(tm-claude src/claude-launcher.mm)
target_link_libraries(tm-claude PRIVATE "-framework Foundation")
add_executable(tm-opencode src/opencode-launcher.mm)
target_link_libraries(tm-opencode PRIVATE "-framework Foundation")

if(BUILD_TESTING)
  find_package(Python3 COMPONENTS Interpreter QUIET)
  if(Python3_Interpreter_FOUND)
    add_executable(textmate-mcp-tool-surface tests/tool_surface_check.mm)
    target_link_libraries(textmate-mcp-tool-surface PRIVATE "-framework Foundation")
    # The drift test compares the three hand-maintained tool lists and asks this
    # helper which names validate_arguments actually accepts.
    add_test(NAME textmate-mcp
      COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_mcp.py
        $<TARGET_FILE:textmate-mcp> $<TARGET_FILE:textmate-mcp-tool-surface>)
  endif()
endif()

# Optional interoperability check using an SDK installed separately for development.
set(TEXTMATE_MCP_SDK_DIR "" CACHE PATH "MCP SDK dist/esm directory for interoperability tests")
if(BUILD_TESTING AND TEXTMATE_MCP_SDK_DIR)
  find_program(TEXTMATE_NODE_EXECUTABLE node REQUIRED)
  add_test(NAME textmate-mcp-sdk
    COMMAND ${TEXTMATE_NODE_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_sdk.mjs
      ${TEXTMATE_MCP_SDK_DIR} $<TARGET_FILE:textmate-mcp>)
endif()
