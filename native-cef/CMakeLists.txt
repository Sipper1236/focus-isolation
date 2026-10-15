cmake_minimum_required(VERSION 3.21)
project(FocusBrowser LANGUAGES C CXX OBJCXX)
if(NOT APPLE)
  message(FATAL_ERROR "Build this native prototype on macOS.")
endif()
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(USE_SANDBOX ON CACHE BOOL "Chromium sandbox must remain enabled" FORCE)
list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)
add_subdirectory("${CEF_LIBCEF_DLL_WRAPPER_PATH}" libcef_dll_wrapper)

set(CEF_APP "${CMAKE_BINARY_DIR}/bin/FocusBrowser.app")
set(EXECUTABLE_NAME FocusBrowser)
set(PRODUCT_NAME "Focus Browser")
add_executable(FocusBrowser MACOSX_BUNDLE browser.mm)
SET_EXECUTABLE_TARGET_PROPERTIES(FocusBrowser)
target_compile_options(FocusBrowser PRIVATE ${CEF_COMPILER_FLAGS} ${CEF_CXX_COMPILER_FLAGS} -fobjc-arc)
target_link_libraries(FocusBrowser PRIVATE libcef_dll_wrapper ${CEF_STANDARD_LIBS})
set_target_properties(FocusBrowser PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in")
COPY_MAC_FRAMEWORK(FocusBrowser "${CEF_BINARY_DIR}" "${CEF_APP}")

# Helper roles and packaging follow the pinned CEF binary distribution template.
foreach(_suffix_list ${CEF_HELPER_APP_SUFFIXES})
  string(REPLACE ":" ";" _parts "${_suffix_list}")
  list(GET _parts 0 _name_suffix)
  list(GET _parts 1 _target_suffix)
  list(GET _parts 2 _plist_suffix)
  set(_target "FocusBrowser_Helper${_target_suffix}")
  set(_name "FocusBrowser Helper${_name_suffix}")
  set(_plist "${CMAKE_CURRENT_BINARY_DIR}/helper${_target_suffix}.plist")
  set(HELPER_EXECUTABLE "${_name}")
  set(HELPER_SUFFIX "${_plist_suffix}")
  configure_file(helper.plist.in "${_plist}" @ONLY)
  add_executable(${_target} MACOSX_BUNDLE helper.cc)
  SET_EXECUTABLE_TARGET_PROPERTIES(${_target})
  target_link_libraries(${_target} PRIVATE libcef_dll_wrapper ${CEF_STANDARD_LIBS})
  set_target_properties(${_target} PROPERTIES OUTPUT_NAME "${_name}" MACOSX_BUNDLE_INFO_PLIST "${_plist}")
  add_dependencies(FocusBrowser ${_target})
  add_custom_command(TARGET FocusBrowser POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
      "${CMAKE_BINARY_DIR}/bin/${_name}.app" "${CEF_APP}/Contents/Frameworks/${_name}.app" VERBATIM)
endforeach()
add_custom_command(TARGET FocusBrowser POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CEF_APP}/Contents/Resources"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/../diagnostic"
          "${CEF_APP}/Contents/Resources/diagnostic"
  COMMAND ${CMAKE_COMMAND} -E copy "${CEF_ROOT}/LICENSE.txt" "${CEF_APP}/Contents/Resources/CEF-LICENSE.txt"
  COMMAND ${CMAKE_COMMAND} -E copy "${CEF_ROOT}/CREDITS.html" "${CEF_APP}/Contents/Resources/CEF-CREDITS.html"
  VERBATIM)
