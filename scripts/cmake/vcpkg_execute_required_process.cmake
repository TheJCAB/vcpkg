function(vcpkg_execute_required_process)
    cmake_parse_arguments(PARSE_ARGV 0 arg
        "ALLOW_IN_DOWNLOAD_MODE"
        "WORKING_DIRECTORY;LOGNAME;TIMEOUT;OUTPUT_VARIABLE;ERROR_VARIABLE"
        "COMMAND"
    )

    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(WARNING "${CMAKE_CURRENT_FUNCTION} was passed extra arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()
    foreach(required_arg IN ITEMS WORKING_DIRECTORY COMMAND)
        if(NOT DEFINED arg_${required_arg})
            message(FATAL_ERROR "${required_arg} must be specified.")
        endif()
    endforeach()

    if(NOT DEFINED arg_LOGNAME)
        message(WARNING "LOGNAME should be specified.")
        set(arg_LOGNAME "required")
    endif()

    if (VCPKG_DOWNLOAD_MODE AND NOT arg_ALLOW_IN_DOWNLOAD_MODE)
        message(FATAL_ERROR
[[
This command cannot be executed in Download Mode.
Halting portfile execution.
]])
    endif()

    set(log_out "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-out.log")
    set(log_err "${CURRENT_BUILDTREES_DIR}/${arg_LOGNAME}-err.log")

    set(timeout_param "")
    set(output_and_error_same OFF)
    set(output_variable_param "")
    set(error_variable_param "")

    if(DEFINED arg_TIMEOUT)
        set(timeout_param TIMEOUT "${arg_TIMEOUT}")
    endif()
    if(DEFINED arg_OUTPUT_VARIABLE AND DEFINED arg_ERROR_VARIABLE AND arg_OUTPUT_VARIABLE STREQUAL arg_ERROR_VARIABLE)
        set(output_variable_param OUTPUT_VARIABLE out_err_var)
        set(error_variable_param ERROR_VARIABLE out_err_var)
        set(output_and_error_same ON)
    else()
        if(DEFINED arg_OUTPUT_VARIABLE)
            set(output_variable_param OUTPUT_VARIABLE out_var)
        endif()
        if(DEFINED arg_ERROR_VARIABLE)
            set(error_variable_param ERROR_VARIABLE err_var)
        endif()
    endif()

    vcpkg_execute_in_download_mode(
        COMMAND ${arg_COMMAND}
        OUTPUT_FILE "${log_out}"
        ERROR_FILE "${log_err}"
        RESULT_VARIABLE error_code
        WORKING_DIRECTORY "${arg_WORKING_DIRECTORY}"
        ${timeout_param}
        ${output_variable_param}
        ${error_variable_param}
    )
    if(NOT error_code EQUAL 0)
        set(stringified_logs "")
        foreach(log IN ITEMS "${log_out}" "${log_err}")
            if(NOT EXISTS "${log}")
                continue()
            endif()
            file(SIZE "${log}" log_size)
            if(NOT log_size EQUAL "0")
                file(TO_NATIVE_PATH "${log}" native_log)
                string(APPEND stringified_logs "    ${native_log}\n")
                file(APPEND "${Z_VCPKG_ERROR_LOG_COLLECTION_FILE}" "${native_log}\n")
            endif()
        endforeach()

        z_vcpkg_prettify_command_line(pretty_command ${arg_COMMAND})
        message(FATAL_ERROR
            "  Command failed: ${pretty_command}\n"
            "  Working Directory: ${arg_WORKING_DIRECTORY}\n"
            "  Error code: ${error_code}\n"
            "  See logs for more information:\n"
            "${stringified_logs}"
        )
    endif()

    # pass output parameters back to caller's scope
    if(output_and_error_same)
        z_vcpkg_forward_output_variable(arg_OUTPUT_VARIABLE out_err_var)
        # arg_ERROR_VARIABLE = arg_OUTPUT_VARIABLE, so no need to set it again
    else()
        z_vcpkg_forward_output_variable(arg_OUTPUT_VARIABLE out_var)
        z_vcpkg_forward_output_variable(arg_ERROR_VARIABLE err_var)
    endif()
endfunction()
