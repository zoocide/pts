@echo off
set pts=perl ..\bin\pts.pl
%pts% -Ttasks -I. %*
