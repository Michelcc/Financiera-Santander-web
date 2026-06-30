@echo off
cd /d "%~dp0"
echo Iniciando Core Mobile API en http://127.0.0.1:8003
python -m pip install -r requirements.txt -q
python -m uvicorn main:app --host 0.0.0.0 --port 8003 --reload
pause
