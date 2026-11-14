@echo off
chcp 65001 >nul
title Universal Translator Pro — Servidor iOS (iPhone PWA + Atalhos)
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    py -3.12 -m venv .venv 2>nul || python -m venv .venv
    ".venv\Scripts\python.exe" -m pip install --upgrade pip httpx
)

".venv\Scripts\python.exe" ios_pwa_bridge\app.py
pause
