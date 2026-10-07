@echo off
title America Online
cd /d "%~dp0"
if not exist "AmericaOnline.exe" (
  echo AmericaOnline.exe is missing from this folder.
  pause
  exit /b 1
)
start "" "%~dp0AmericaOnline.exe"
