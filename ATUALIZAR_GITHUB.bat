@echo off
chcp 65001 >nul
title Atualizar Workflow iOS no GitHub (macos-15)
cd /d "%~dp0"

echo Enviando correcao do runner macos-15 para o GitHub...
git add .
git commit -m "Fix GitHub Actions runner: migrate from retired macos-14 to macos-15"
git push

echo.
echo Pronto! Acesse https://github.com/eduardxsilva/universal-translator-ios/actions para acompanhar o build.
pause
