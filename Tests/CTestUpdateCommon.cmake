#-----------------------------------------------------------------------------
# Function to run a child process and report output only on error.
function(run_child)
  execute_process(${ARGN}
    RESULT_VARIABLE FAILED
    OUTPUT_VARIABLE OUTPUT
    ERROR_VARIABLE OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
    )
  if(FAILED)
    string(REGEX REPLACE "\n" "\n  " OUTPUT "${OUTPUT}")
    message(FATAL_ERROR "Child failed (${FAILED}), output is\n  ${OUTPUT}\n"
      "Command = [${ARGN}]\n")
  endif(FAILED)
endfunction(run_child)

#-----------------------------------------------------------------------------
# Function to find the Update.xml file and check for expected entries.
function(check_updates build)
  # Find the Update.xml file for the given build tree
  set(PATTERN ${TOP}/${build}/Testing/*/Update.xml)
  file(GLOB UPDATE_XML_FILE RELATIVE ${TOP} ${PATTERN})
  string(REGEX REPLACE "//Update.xml$" "/Update.xml"
    UPDATE_XML_FILE "${UPDATE_XML_FILE}"
    )
  if(NOT UPDATE_XML_FILE)
    message(FATAL_ERROR "Cannot find Update.xml with pattern\n  ${PATTERN}")
  endif(NOT UPDATE_XML_FILE)
  message(" found ${UPDATE_XML_FILE}")

  # Read entries from the Update.xml file
  set(types "Updated|Modified|Conflicting")
  file(STRINGS ${TOP}/${UPDATE_XML_FILE} UPDATE_XML_ENTRIES
    REGEX "<(${types}|FullName)>"
    LIMIT_INPUT 4096
    )
  string(REGEX REPLACE
    "[ \t]*<(${types})>[ \t]*;[ \t]*<FullName>([^<]*)</FullName>"
    "\\1{\\2}" UPDATE_XML_ENTRIES "${UPDATE_XML_ENTRIES}")

  # Compare expected and actual entries
  set(EXTRA "${UPDATE_XML_ENTRIES}")
  list(REMOVE_ITEM EXTRA ${ARGN} ${UPDATE_EXTRA} ${UPDATE_MAYBE})
  set(MISSING "${ARGN}" ${UPDATE_EXTRA})
  list(REMOVE_ITEM MISSING ${UPDATE_XML_ENTRIES})

  if(NOT UPDATE_NOT_GLOBAL)
    set(rev_elements Revision PriorRevision ${UPDATE_GLOBAL_ELEMENTS})
    string(REPLACE ";" "|" rev_regex "${rev_elements}")
    set(rev_regex "^\t<(${rev_regex})>[^<\n]+</(${rev_regex})>$")
    file(STRINGS ${TOP}/${UPDATE_XML_FILE} UPDATE_XML_REVISIONS
      REGEX "${rev_regex}"
      LIMIT_INPUT 4096
      )
    foreach(r IN LISTS UPDATE_XML_REVISIONS)
      string(REGEX REPLACE "${rev_regex}" "\\1" element "${r}")
      set(element_${element} 1)
    endforeach()
    foreach(element ${rev_elements})
      if(NOT element_${element})
        list(APPEND MISSING "global <${element}> element")
      endif()
    endforeach()
  endif()

  # Report the result
  set(MSG "")
  if(MISSING)
    # List the missing entries
    set(MSG "${MSG}Update.xml is missing expected entries:\n")
    foreach(f ${MISSING})
      set(MSG "${MSG}  ${f}\n")
    endforeach(f)
  else(MISSING)
    # Success
    message(" no entries missing from Update.xml")
  endif(MISSING)

  # Report the result
  if(EXTRA)
    # List the extra entries
    set(MSG "${MSG}Update.xml has extra unexpected entries:\n")
    foreach(f ${EXTRA})
      set(MSG "${MSG}  ${f}\n")
    endforeach(f)
  else(EXTRA)
    # Success
    message(" no extra entries in Update.xml")
  endif(EXTRA)

  if(MSG)
    # Provide the log file
    file(GLOB UPDATE_LOG_FILE
      ${TOP}/${build}/Testing/Temporary/LastUpdate*.log)
    if(UPDATE_LOG_FILE)
      file(READ ${UPDATE_LOG_FILE} UPDATE_LOG LIMIT 4096)
      string(REGEX REPLACE "\n" "\n  " UPDATE_LOG "${UPDATE_LOG}")
      set(MSG "${MSG}Update log:\n  ${UPDATE_LOG}")
    else(UPDATE_LOG_FILE)
      set(MSG "${MSG}No update log found!")
    endif(UPDATE_LOG_FILE)

    # Display the error message
    message(FATAL_ERROR "${MSG}")
  endif(MSG)
endfunction(check_updates)

#-----------------------------------------------------------------------------
# Function to create initial content.
function(create_content dir)
  file(MAKE_DIRECTORY ${TOP}/${dir})

  # An example CTest project configuration file.
  file(WRITE ${TOP}/${dir}/CTestConfig.cmake
    "# CTest Configuration File
set(CTEST_PROJECT_NAME TestProject)
set(CTEST_NIGHTLY_START_TIME \"21:00:00 EDT\")
")

  # Some other files.
  file(WRITE ${TOP}/${dir}/foo.txt "foo\n")
  file(WRITE ${TOP}/${dir}/bar.txt "bar\n")
endfunction(create_content)

#-----------------------------------------------------------------------------
# Function to update content.
function(update_content dir added_var removed_var dirs_var)
  file(APPEND ${TOP}/${dir}/foo.txt "foo line 2\n")
  file(WRITE ${TOP}/${dir}/zot.txt "zot\n")
  file(REMOVE ${TOP}/${dir}/bar.txt)
  file(MAKE_DIRECTORY ${TOP}/${dir}/subdir)
  file(WRITE ${TOP}/${dir}/subdir/foo.txt "foo\n")
  file(WRITE ${TOP}/${dir}/subdir/bar.txt "bar\n")
  set(${dirs_var} subdir PARENT_SCOPE)
  set(${added_var} zot.txt subdir/foo.txt subdir/bar.txt PARENT_SCOPE)
  set(${removed_var} bar.txt PARENT_SCOPE)
endfunction(update_content)

#-----------------------------------------------------------------------------
# Function to change existing files
function(change_content dir)
  file(APPEND ${TOP}/${dir}/foo.txt "foo line 3\n")
  file(APPEND ${TOP}/${dir}/subdir/foo.txt "foo line 2\n")
endfunction(change_content)

#-----------------------------------------------------------------------------
# Function to create local modifications before update
function(modify_content dir)
  file(APPEND ${TOP}/${dir}/CTestConfig.cmake "# local modification\n")
endfunction(modify_content)

#-----------------------------------------------------------------------------
# Function to write CTestConfiguration.ini content.
function(create_build_tree src_dir bin_dir)
  file(MAKE_DIRECTORY ${TOP}/${bin_dir})
  file(WRITE ${TOP}/${bin_dir}/CTestConfiguration.ini
    "# CTest Configuration File
SourceDirectory: ${TOP}/${src_dir}
BuildDirectory: ${TOP}/${bin_dir}
Site: test.site
BuildName: user-test
")
endfunction(create_build_tree)

#-----------------------------------------------------------------------------
# Function to write the dashboard test script.
function(create_dashboard_script name custom_text)
  # Write the dashboard script.
  file(WRITE ${TOP}/dashboard.cmake
    "# CTest Dashboard Script
set(CTEST_DASHBOARD_ROOT \"${TOP}\")
set(CTEST_SITE test.site)
set(CTEST_BUILD_NAME dash-test)
set(CTEST_SOURCE_DIRECTORY \${CTEST_DASHBOARD_ROOT}/dash-source)
set(CTEST_BINARY_DIRECTORY \${CTEST_DASHBOARD_ROOT}/dash-binary)
${custom_text}
# Start a dashboard and run the update step
ctest_start(Experimental)
ctest_update(SOURCE \${CTEST_SOURCE_DIRECTORY})
")
endfunction(create_dashboard_script)

#-----------------------------------------------------------------------------
# Function to run the dashboard through the command line
function(run_dashboard_command_line bin_dir)
  run_child(
    WORKING_DIRECTORY ${TOP}/${bin_dir}
    COMMAND ${CMAKE_CTEST_COMMAND} -M Experimental -T Start -T Update
    )

  # Verify the updates reported by CTest.
  list(APPEND UPDATE_MAYBE Updated{subdir})
  check_updates(${bin_dir}
    Updated{foo.txt}
    Updated{bar.txt}
    Updated{zot.txt}
    Updated{subdir/foo.txt}
    Updated{subdir/bar.txt}
    Modified{CTestConfig.cmake}
    )
endfunction(run_dashboard_command_line)

#-----------------------------------------------------------------------------
# Function to run the dashboard through a script
function(run_dashboard_script name)
  run_child(
    WORKING_DIRECTORY ${TOP}
    COMMAND ${CMAKE_CTEST_COMMAND} -S ${name} -V
    )

  # Verify the updates reported by CTest.
  list(APPEND UPDATE_MAYBE Updated{subdir})
  check_updates(dash-binary
    Updated{foo.txt}
    Updated{bar.txt}
    Updated{zot.txt}
    Updated{subdir/foo.txt}
    Updated{subdir/bar.txt}
    )
endfunction(run_dashboard_script)

#-----------------------------------------------------------------------------
# Function to initialize the testing directory.
function(init_testing)
  file(REMOVE_RECURSE ${TOP})
  file(MAKE_DIRECTORY ${TOP})
endfunction(init_testing)
