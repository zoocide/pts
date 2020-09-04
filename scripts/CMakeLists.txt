## set pts launcher name ##
if (WIN32)
  set(PTS_LAUNCHER "pts.bat")
else ()
  set(PTS_LAUNCHER "pts")
endif (WIN32)

configure_file("${PTS_LAUNCHER}.in" "${BINDIR}/${PTS_LAUNCHER}" @ONLY)
configure_file(pts.pl.in "${BINDIR}/pts.pl" @ONLY)

# CMAKE_INSTALL_FULL_BINDIR - ???

install(
  FILES
    "${BINDIR}/${PTS_LAUNCHER}"
    "${BINDIR}/pts.pl"
  DESTINATION
    "${CMAKE_INSTALL_FULL_BINDIR}"
  PERMISSIONS
    OWNER_WRITE OWNER_READ OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE
)
