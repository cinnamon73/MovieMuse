# API Security Setup

## 🔐 Secure API Key Management

This app uses **environment variables** to securely manage the TMDB API key, preventing it from being exposed in the source code.

## 🚀 Quick Setup

### Option 1: Automated Setup (Unix/Mac/Linux)
```bash
chmod +x setup_env.sh
./setup_env.sh
```

### Option 2: Manual Setup
1. **Create a `.env` file** in the project root:
```bash
touch .env
```

2. **Add your TMDB API key** to the `.env` file:
```env
# TMDB API Configuration
TMDB_API_KEY=your_actual_api_key_here
```

3. **Get dependencies**:
```bash
flutter pub get
```

## 🔑 Getting a TMDB API Key

1. Go to [TMDB API Settings](https://www.themoviedb.org/settings/api)
2. Create an account if you don't have one
3. Request an API key (it's free!)
4. Copy your API key
5. Replace `your_actual_api_key_here` in your `.env` file

## 🛡️ Security Features

- ✅ **API key never in source code** - stored in `.env` file
- ✅ **Automatically ignored by Git** - `.env` is in `.gitignore`
- ✅ **Runtime validation** - app checks if key is loaded
- ✅ **Error handling** - graceful fallback if key is missing

## ⚠️ Important Notes

- **Never commit your `.env` file** to version control
- **Don't share your API key** with others
- **Use your own API key** - don't use someone else's
- **Keep your key secure** - treat it like a password

## 🔧 Development

The app will:
- ✅ Load the API key from `.env` on startup
- ✅ Validate the key exists before making API calls
- ✅ Show helpful error messages if the key is missing
- ✅ Log successful initialization for debugging

## 📁 File Structure

```
movie_picker/
├── .env                 # Your API key (NOT in Git)
├── .gitignore          # Contains .env (prevents commits)
├── setup_env.sh        # Automated setup script
└── lib/
    ├── main.dart       # Loads environment variables
    └── services/
        └── movie_service.dart  # Uses env variables
```

## 🚨 Troubleshooting

### Error: "TMDB API key not found in environment variables"
1. Make sure you have a `.env` file in the project root
2. Check that `TMDB_API_KEY=your_key` is in the file
3. Run `flutter clean && flutter pub get`
4. Restart your app

### Error: "Could not load .env file"
1. Make sure `.env` is in your `pubspec.yaml` assets
2. Check that `.env` exists in the project root
3. Run `flutter pub get`

## 🏗️ Production Deployment

For production apps, consider:
- Using CI/CD environment variables
- Cloud-based secret management
- API key rotation policies
- Rate limiting and monitoring 