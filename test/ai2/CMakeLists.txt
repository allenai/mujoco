if(NOT TARGET mujoco::mujoco)
    message(WARNING "Target mujoco::mujoco must be defined")
    return()
endif()

include(${CMAKE_SOURCE_DIR}/cmake/wilbertp/common.cmake)

FetchContent_Declare(
  cli11
  GIT_REPOSITORY https://github.com/CLIUtils/CLI11.git
  GIT_TAG 457839d482455e746faabc07e2e6fa4c30f2d553
)
FetchContent_MakeAvailable(cli11)

set(TESTS_AI2_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/test_segmentation.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/test_render_filament.cc
)

foreach(ex_filepath IN LISTS TESTS_AI2_LIST)
  wp_setup_single_file_example(${ex_filepath}
    TARGET_DEPENDENCIES
    mujoco::mujoco
    mujoco::filament
    CLI11::CLI11)
endforeach()

