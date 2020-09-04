## set pts launcher name ##
if (WIN32)
  set(PTS_EXECUTABLE "pts.bat")
else ()
  set(PTS_EXECUTABLE "pts")
endif (WIN32)
set(PTS_PL "${BINDIR}/pts.pl")

configure_file("${PTS_EXECUTABLE}.in" "${BINDIR}/${PTS_EXECUTABLE}" @ONLY)
configure_file(pts.pl.in "${BINDIR}/pts.pl" @ONLY)

if (0)
install(
  FILES
    "${BINDIR}/${PTS_EXECUTABLE}"
    "${BINDIR}/pts.pl"
  DESTINATION
    #"${CMAKE_INSTALL_FULL_BINDIR}"
  PERMISSIONS
    OWNER_WRITE OWNER_READ OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE
)
endif(0)
