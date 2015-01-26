set PATH=%CD%\bison\bin;c:\program files\git\bin;c:\program files (x86)\git\bin;%PATH%
for %%i in (bison.exe) do set BISON_PATH=%%~$PATH:i
if "%BISON_PATH%"=="" (
  mkdir bison 2> NUL
  echo downloading bison...
  powershell -Command "$web_client = New-Object System.Net.WebClient; $web_client.DownloadFile('http://downloads.sourceforge.net/gnuwin32/bison-2.4.1-bin.zip', 'bison-2.4.1-bin.zip'); $web_client.DownloadFile('http://downloads.sourceforge.net/gnuwin32/bison-2.4.1-dep.zip', 'bison-2.4.1-dep.zip');"
  powershell -Command "$sh = new-object -com shell.application; $sh.namespace('%CD%\bison').CopyHere($sh.namespace('%CD%\bison-2.4.1-bin.zip').Items(), 16)"
  powershell -Command "$sh = new-object -com shell.application; $sh.namespace('%CD%\bison').CopyHere($sh.namespace('%CD%\bison-2.4.1-dep.zip').Items(), 16)"
)
bison %*
