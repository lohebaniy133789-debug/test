@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem ================================================================
rem  russiansoundcloud-music - сборщик музыкального мода для ReSkate (skate.)
rem
rem  Если игра стоит не в D:\RESKATE - поправь строку GAME ниже
rem  (это папка, где лежит Skate.exe и папка Mods).
rem ================================================================
set "MOD_NAME=russiansoundcloud-music"
set "MOD_DIR=russiansoundcloud-music"
set "GAME=D:\RESKATE"

set "KIT=%~dp0"
set "KIT=%KIT:~0,-1%"
set "MUSIC=%KIT%\music"
if not "%~1"=="" set "MUSIC=%~1"
set "OUT=%GAME%\Mods\%MOD_DIR%"

title russiansoundcloud-music - сборка мода
echo.
echo    ==============================
echo      russiansoundcloud-music
echo      музыкальный мод для ReSkate
echo    ==============================
echo.

rem ---------- игра ----------
if exist "%GAME%\Skate.exe" goto :game_ok
echo [!] Не нашёл Skate.exe в "%GAME%".
echo     Открой этот файл Блокнотом и поправь строку: set "GAME=..."
goto :fail
:game_ok
echo [ok] Игра: %GAME%

rem ---------- ReSkate Music Packer ----------
set "PACKER="
for /f "delims=" %%F in ('dir /s /b "%KIT%\ReSkateMusicPacker.exe" 2^>nul') do if not defined PACKER set "PACKER=%%F"
if defined PACKER goto :packer_ok
echo [!] Не нашёл ReSkateMusicPacker.exe рядом с этим файлом.
echo     Скачай его тут (Windows-версия, последний релиз):
echo     https://github.com/DeckardDetribine/ReSkateMusicPacker/releases
echo     и распакуй в эту папку: "%KIT%"
start "" "https://github.com/DeckardDetribine/ReSkateMusicPacker/releases"
goto :fail
:packer_ok
echo [ok] Упаковщик: %PACKER%

rem ---------- треки ----------
if exist "%MUSIC%\" goto :music_dir_ok
mkdir "%MUSIC%"
echo [!] Создал папку для треков: "%MUSIC%"
echo     Закинь туда свою музыку и запусти меня ещё раз.
start "" "%MUSIC%"
goto :fail
:music_dir_ok

set "COUNT=0"
set "JUNK=0"
for %%A in ("%MUSIC%\*") do call :check_file "%%~xA" "%%~nxA"
if %JUNK% GTR 0 goto :junk
if %COUNT% GTR 0 goto :music_ok
echo [!] В папке "%MUSIC%" нет треков.
echo     Подходят: mp3, flac, wav, ogg, opus, m4a, aac, wma, aiff, webm, mka, mp4.
start "" "%MUSIC%"
goto :fail
:junk
echo [!] В папке с треками лежат лишние файлы - их надо убрать
echo     (картинки можно оставить, всё остальное мешает сборке).
start "" "%MUSIC%"
goto :fail
:music_ok
echo [ok] Треков: %COUNT%  (папка: %MUSIC%)

rem ---------- ffmpeg ----------
where ffmpeg >nul 2>&1 && where ffprobe >nul 2>&1 && goto :ffmpeg_ok
set "FFROOT=%KIT%\ffmpeg"
set "FFBIN="
for /f "delims=" %%F in ('dir /s /b "%FFROOT%\ffmpeg.exe" 2^>nul') do if not defined FFBIN set "FFBIN=%%~dpF"
if defined FFBIN goto :ffmpeg_path
echo [..] ffmpeg не найден - качаю его один раз, подожди...
"%PACKER%" --get-ffmpeg "%FFROOT%"
for /f "delims=" %%F in ('dir /s /b "%FFROOT%\ffmpeg.exe" 2^>nul') do if not defined FFBIN set "FFBIN=%%~dpF"
if defined FFBIN goto :ffmpeg_path
echo [!] Не получилось скачать ffmpeg.
echo     Запусти ReSkateMusicPacker.exe двойным кликом и нажми
echo     "Download ffmpeg automatically", потом запусти меня снова.
goto :fail
:ffmpeg_path
set "PATH=%FFBIN%;%PATH%"
:ffmpeg_ok
echo [ok] ffmpeg на месте

rem ---------- обложка плейлиста ----------
set COVER_ARGS=--generate-playlist-artwork "%MOD_NAME%"
if exist "%KIT%\cover.png" set COVER_ARGS=--playlist-artwork "%MOD_NAME%" "%KIT%\cover.png"
if exist "%KIT%\cover.jpg" set COVER_ARGS=--playlist-artwork "%MOD_NAME%" "%KIT%\cover.jpg"

rem ---------- сборка ----------
echo.
echo [..] Собираю мод "%MOD_NAME%" в "%OUT%"
echo      Первый раз может занять несколько минут - треки перекодируются.
echo.
"%PACKER%" "%GAME%" "%MUSIC%" "%OUT%" --name "%MOD_NAME%" --playlist "%MOD_NAME%" %COVER_ARGS%
if errorlevel 1 goto :build_fail
if not exist "%OUT%\reskate-music.json" goto :build_fail

echo.
echo    ==============================
echo     ГОТОВО! Мод лежит тут:
echo     %OUT%
echo.
echo     1. Открой лаунчер ReSkate - вкладка MODS
echo     2. Включи "%MOD_NAME%"
echo     3. В игре: меню музыки - плейлист "%MOD_NAME%"
echo    ==============================
echo.
pause
exit /b 0

:build_fail
echo.
echo [!] Сборка не удалась - посмотри сообщения выше.
goto :fail

:fail
echo.
pause
exit /b 1

rem %1 = расширение файла, %2 = имя файла
:check_file
for %%E in (.mp3 .flac .wav .ogg .opus .m4a .aac .wma .aiff .aif .webm .mka .mp4) do if /i "%~1"=="%%E" set /a COUNT+=1 & exit /b 0
for %%E in (.png .jpg .jpeg .webp .bmp) do if /i "%~1"=="%%E" exit /b 0
echo     лишний файл: %~2
set /a JUNK+=1
exit /b 0
