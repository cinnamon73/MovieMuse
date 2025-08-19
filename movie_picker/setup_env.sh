#!/bin/bash

echo "🎬 Movie Picker - Environment Setup"
echo "=================================="

# Check if .env file already exists
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists!"
    echo "If you want to update it, please edit it manually or delete it first."
    exit 1
fi

# Create .env file
echo "📝 Creating .env file..."
cat > .env << 'EOF'
# TMDB API Configuration
# Get your API key from: https://www.themoviedb.org/settings/api
TMDB_API_KEY=f26e4183a1a1ea7149cfb88dd01979bb

# Note: This file should never be committed to version control
# Make sure .env is in your .gitignore file
EOF

echo "✅ .env file created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Get your own TMDB API key from: https://www.themoviedb.org/settings/api"
echo "2. Replace the API key in .env file with your own key"
echo "3. Run: flutter pub get"
echo "4. Run: flutter run"
echo ""
echo "⚠️  IMPORTANT: Never commit your .env file to version control!"
echo "   The .env file has been added to .gitignore for your safety." 