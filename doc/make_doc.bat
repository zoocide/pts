@echo off
set css_url=../styles/style.css
set opts=--htmldir=html --podroot=.. --podpath=modules
set mod_dir=../modules/
set html_dir=html/modules/
set css_mod_url=../%css_url%

call perl -MExtUtils::Command -e mkpath %html_dir%external
call perl -MExtUtils::Command -e mkpath %html_dir%Task
call perl -MExtUtils::Command -e mkpath %html_dir%Plugins
call perl -MExtUtils::Command -e mkpath %html_dir%Plugins/Base

call pod2html %opts% %mod_dir%pts.pod --outfile=html/index.html --css=%css_url%
call pod2html %opts% %mod_dir%TaskDB.pm --outfile=%html_dir%TaskDB.html --css=%css_mod_url%
call pod2html %opts% %mod_dir%Task.pm --outfile=%html_dir%Task.html --css=%css_mod_url%
call pod2html %opts% %mod_dir%Task/ID.pm --outfile=%html_dir%Task/ID.html --css=../%css_mod_url%
call pod2html %opts% %mod_dir%MyConsoleColors.pm --outfile=%html_dir%MyConsoleColors.html --css=%css_mod_url%
call pod2html %opts% %mod_dir%PtsColorScheme.pm --outfile=%html_dir%PtsColorScheme.html --css=%css_mod_url%
call pod2html %opts% %mod_dir%Plugins/Base.pm --outfile=%html_dir%Plugins/Base.html --css=../%css_mod_url%
call pod2html %opts% %mod_dir%Plugins/Base/Util.pm --outfile=%html_dir%Plugins/Base/Util.html --css=../../%css_mod_url%
call pod2html %opts% %mod_dir%external/ConfigFile.pm --outfile=%html_dir%external/ConfigFile.html --css=../%css_mod_url%
call pod2html %opts% %mod_dir%external/ConfigFileScheme.pm --outfile=%html_dir%external/ConfigFileScheme.html --css=../%css_mod_url%
call pod2html %opts% %mod_dir%external/CmdArgs.pm --outfile=%html_dir%external/CmdArgs.html --css=../%css_mod_url%
