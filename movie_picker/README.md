# Movie Picker App

A Flutter application for discovering and filtering movies using the TMDB API with personalized recommendations.

## Features

- **Movie Discovery**: Swipeable movie cards with TMDB data
- **Smart Filtering**: Genre, language, release year, and person-based filters
- **Personalized Recommendations**: AI-powered recommendations based on your viewing history
- **User Profiles**: Multiple user support with individual preferences
- **Privacy-First**: GDPR/CCPA compliant with local data storage
- **Adult Content Control**: Optional adult content filtering
- **Comprehensive Movie Details**: Cast, crew, ratings, and detailed information

## How to Use

### Basic Navigation
- **Swipe Right**: Mark movie as watched
- **Swipe Left**: Skip movie (not interested)
- **Swipe Up**: View detailed movie information
- **Swipe Down**: Bookmark movie for later

### Filtering Options
- **Genre Filter**: Filter by specific movie genres
- **Language Filter**: Filter by original language
- **Time Period Filter**: Filter by release decade
- **Person Filter**: Find movies by specific actors or directors
- **Rating Filter**: Filter by minimum TMDB rating

### Tabs
- **Trending**: Popular movies with applied filters
- **For You**: Personalized recommendations based on your viewing history

## Setup Instructions

1. **Get TMDB API Key**:
   - Sign up at [The Movie Database](https://www.themoviedb.org/)
   - Get your API key from your account settings

2. **Environment Setup**:
   - Create a `.env` file in the project root
   - Add your API key: `TMDB_API_KEY=your_api_key_here`

3. **Run the App**:
   ```bash
   flutter pub get
   flutter run
   ```

## Privacy & Security

- **Local Data Storage**: All user data stored locally on device
- **Encrypted Storage**: Sensitive data encrypted with AES-256
- **GDPR Compliant**: Full data export and deletion capabilities
- **Privacy Policy**: Built-in privacy policy with user consent
- **No Tracking**: No external analytics or user tracking

## Technical Features

- **Offline Caching**: Movie data cached for offline viewing
- **Performance Optimized**: Efficient API calls with request deduplication
- **Responsive UI**: Works on multiple screen sizes
- **Accessibility**: Screen reader support and high contrast

## Dependencies

- Flutter SDK
- TMDB API for movie data
- Secure storage for user data encryption
- Cached network images for performance

## Contributing

This is a personal project. Feel free to fork and modify for your own use.

## License

This project is for educational and personal use only. Movie data provided by TMDB.
