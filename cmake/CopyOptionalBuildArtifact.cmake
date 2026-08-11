if(NOT DEFINED SOURCE OR NOT DEFINED DESTINATION)
    message(FATAL_ERROR "SOURCE and DESTINATION are required")
endif()

if(EXISTS "${SOURCE}")
    file(COPY_FILE "${SOURCE}" "${DESTINATION}" ONLY_IF_DIFFERENT)
elseif(EXISTS "${DESTINATION}")
    # Never leave a stale symbol file beside a newly linked plugin.
    file(REMOVE "${DESTINATION}")
endif()
