cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Make sure the real Flutter engine headers are first on the include path:
if(DEFINED ENV{FLUTTER_ROOT})
  include_directories("$ENV{FLUTTER_ROOT}/bin/cache/artifacts/engine/linux-x64/include")
endif()

# Define the application target.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. IMPORTANT: Ensure these are correct.
target_link_libraries(${BINARY_NAME} PRIVATE 
flutter
PkgConfig::GTK
)

# Set include directories.
# The flutter_wrapper_app and flutter_wrapper_plugin targets should bring
# their own INTERFACE_INCLUDE_DIRECTORIES when linked.
# We only explicitly include the current source directory for runner's own headers.
target_include_directories(${BINARY_NAME} PRIVATE 
"${CMAKE_SOURCE_DIR}"
"${FLUTTER_MANAGED_DIR}" 
"${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral"


)