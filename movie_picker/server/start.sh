#!/bin/bash

echo "🚀 Starting Movie Picker Streaming Filter Server..."
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install dependencies."
        exit 1
    fi
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found. Creating from template..."
    cp env.example .env
    echo
    echo "📝 Please edit .env file and add your TMDB API key:"
    echo "   TMDB_API_KEY=your_tmdb_api_key_here"
    echo
    read -p "Press Enter to continue..."
fi

echo "✅ Starting server in development mode..."
echo "🌐 Server will be available at: http://localhost:3001"
echo "📋 Health check: http://localhost:3001/health"
echo "🎬 Streaming filter: http://localhost:3001/filter/streaming"
echo
echo "Press Ctrl+C to stop the server"
echo

npm run dev 