@echo off
set css_url=https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css
set opts=--htmldir=html --podroot=.. --podpath=modules --css=%css_url%
set mod_dir=../modules/
set html_dir=html/modules/
set css=https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css

call perl -MExtUtils::Command -e mkpath %html_dir%external
call perl -MExtUtils::Command -e mkpath %html_dir%Task
call perl -MExtUtils::Command -e mkpath %html_dir%Plugins

call pod2html %opts% %mod_dir%pts.pod --outfile=html/index.html
call pod2html %opts% %mod_dir%TaskDB.pm --outfile=%html_dir%TaskDB.html
call pod2html %opts% %mod_dir%Task.pm --outfile=%html_dir%Task.html
call pod2html %opts% %mod_dir%Task/ID.pm --outfile=%html_dir%Task/ID.html
call pod2html %opts% %mod_dir%Plugins/Base.pm --outfile=%html_dir%Plugins/Base.html
call pod2html %opts% %mod_dir%external/ConfigFile.pm --outfile=%html_dir%external/ConfigFile.html
call pod2html %opts% %mod_dir%external/ConfigFileScheme.pm --outfile=%html_dir%external/ConfigFileScheme.html
call pod2html %opts% %mod_dir%external/CmdArgs.pm --outfile=%html_dir%external/CmdArgs.html

rem TODO: Add `body { max-width : 960px; }` to the style.
