if(NOT TARGET mujoco::mujoco)
    message(WARNING "Target mujoco::mujoco must be defined")
    return()
endif()

include(${CMAKE_SOURCE_DIR}/cmake/wilbertp/common.cmake)

set(SINGLE_FILE_EXAMPLES
    "${CMAKE_CURRENT_SOURCE_DIR}/ex_diffik.cc"
)

foreach(ex_filepath IN LISTS SINGLE_FILE_EXAMPLES)
    wp_setup_single_file_example(
        ${ex_filepath}
        TARGET_DEPENDENCIES
        mujoco::mujoco
        mujoco::filament
    )
endforeach()

