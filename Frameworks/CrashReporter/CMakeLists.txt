add_library(CrashReporter STATIC)
file(GLOB _src src/*.mm)
target_sources(CrashReporter PRIVATE ${_src})
textmate_framework(CrashReporter)
target_link_libraries(CrashReporter PUBLIC Preferences
  "-framework Foundation" "-framework UserNotifications")
find_library(ZLIB z REQUIRED)
target_link_libraries(CrashReporter PRIVATE ${ZLIB})
