@echo off
rem Перемешивает треки мода заново: первые треки из order.txt остаются на своих местах.
call "%~dp0build-mod.bat" /shuffle
