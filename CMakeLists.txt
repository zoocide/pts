cmake_minimum_required(VERSION 3.10)
project(PTS VERSION 0.5.1)

set(PTS_INSTALL_DIR ${CMAKE_SOURCE_DIR} CACHE PATH "The directory where PTS will be installed.")

## find perl ##
find_package(Perl)
if(NOT PERL_FOUND)
	message(FATAL_ERROR "PTS requires Perl 5.10.1 or newer but it was not found on your system.")
endif(NOT PERL_FOUND)

# Checking for perl modules requires FindPerlModules.cmake
# Check all required modules at once
#find_package(PerlModules COMPONENTS
#  File::chdir Time::HiRes
#)
#if(NOT PERLMODULES_FOUND)
#	message(FATAL_ERROR "Not all required perl modules were found on your system")
#endif(NOT PERLMODULES_FOUND)

set(BINDIR "${CMAKE_SOURCE_DIR}/bin")
add_subdirectory(scripts)
