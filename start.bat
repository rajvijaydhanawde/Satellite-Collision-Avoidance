@echo off
title OrbitGuard — Satellite Collision Avoidance
color 0A
echo.
echo  ============================================
echo   OrbitGuard v3 — Satellite Collision Avoidance
echo  ============================================
echo.

:: ── Check Python ────────────────────────────────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python not found. Install from https://python.org
    pause
    exit /b
)

:: ── Install backend dependencies ─────────────────────────────────────────────
echo  [1/3] Installing backend dependencies...
cd /d "%~dp0backend"
pip install fastapi uvicorn numpy scipy sgp4 python-multipart --quiet --no-warn-script-location
if errorlevel 1 (
    echo  [WARN] Some packages may have failed. Continuing...
)

:: ── Start backend in a new window ────────────────────────────────────────────
echo  [2/3] Starting API backend on http://localhost:8000 ...
start "OrbitGuard Backend" cmd /k "cd /d "%~dp0backend" && python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload"

:: ── Wait for backend to start ────────────────────────────────────────────────
echo  [3/3] Waiting for backend to start...
timeout /t 4 /nobreak >nul

:: ── Start frontend ────────────────────────────────────────────────────────────
echo  Starting frontend on http://localhost:3000 ...
start "OrbitGuard Frontend" cmd /k "cd /d "%~dp0frontend" && python -m http.server 3000"

:: ── Open browser ─────────────────────────────────────────────────────────────
timeout /t 2 /nobreak >nul
start http://localhost:3000

echo.
echo  ============================================
echo   OrbitGuard is running!
echo.
echo   Frontend : http://localhost:3000
echo   Backend  : http://localhost:8000
echo   API Docs : http://localhost:8000/docs
echo  ============================================
echo.
echo  Close this window to stop. (Backend and Frontend
echo  are running in separate windows.)
echo.
pause
