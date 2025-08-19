@echo off
echo 🚀 Starting Movie Picker Streaming Filter Server...
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed. Please install Node.js first.
    pause
    exit /b 1
)

REM Check if dependencies are installed
if not exist "node_modules" (
    echo 📦 Installing dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo ❌ Failed to install dependencies.
        pause
        exit /b 1
    )
)

REM Check if .env file exists
if not exist ".env" (
    echo ⚠️  .env file not found. Creating from template...
    copy env.example .env
    echo.
    echo 📝 Please edit .env file and add your TMDB API key:
    echo    TMDB_API_KEY=your_tmdb_api_key_here
    echo.
    pause
)

echo ✅ Starting server in development mode...
echo 🌐 Server will be available at: http://localhost:3001
echo 📋 Health check: http://localhost:3001/health
echo 🎬 Streaming filter: http://localhost:3001/filter/streaming
echo.
echo Press Ctrl+C to stop the server
echo.

npm run dev 