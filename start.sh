#!/bin/bash
# OrbitGuard — one-command startup for Mac/Linux

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo " ============================================"
echo "  OrbitGuard v3 — Satellite Collision Avoidance"
echo " ============================================"
echo ""

# Check Python
if ! command -v python3 &>/dev/null; then
    echo " [ERROR] python3 not found. Install from https://python.org"; exit 1
fi

# Install dependencies
echo " [1/3] Installing backend dependencies..."
cd "$SCRIPT_DIR/backend"
pip3 install fastapi uvicorn numpy scipy sgp4 python-multipart -q

# Start backend
echo " [2/3] Starting backend on http://localhost:8000 ..."
python3 -m uvicorn api.main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
echo "       Backend PID: $BACKEND_PID"

# Wait for backend
sleep 3

# Start frontend
echo " [3/3] Starting frontend on http://localhost:3000 ..."
cd "$SCRIPT_DIR/frontend"
python3 -m http.server 3000 &
FRONTEND_PID=$!
echo "       Frontend PID: $FRONTEND_PID"

sleep 1

# Open browser
echo ""
echo " Opening browser..."
if command -v xdg-open &>/dev/null; then
    xdg-open http://localhost:3000
elif command -v open &>/dev/null; then
    open http://localhost:3000
fi

echo ""
echo " ============================================"
echo "  Running!"
echo ""
echo "  Frontend : http://localhost:3000"
echo "  Backend  : http://localhost:8000"
echo "  API Docs : http://localhost:8000/docs"
echo " ============================================"
echo ""
echo " Press Ctrl+C to stop both servers."
echo ""

# Keep running, cleanup on exit
trap "echo 'Stopping...'; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" INT TERM
wait
