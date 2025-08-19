# Streaming Server Integration Guide

This guide explains how to integrate the new server-side streaming filter into your existing Flutter app.

## Overview

The new server-side streaming filter solves performance issues by:
1. **Eliminating redundant API calls** - No more individual `/movie/{id}/watch/providers` calls
2. **Using TMDB's native filtering** - Leverages `with_watch_providers` parameter directly
3. **Providing intelligent caching** - Reduces API calls and improves response times
4. **Supporting regional accuracy** - Proper handling of regional availability differences

## What's New

### 1. Server-Side Components
- **Express.js server** (`movie_picker/server/`) - Handles streaming filtering
- **Platform mapping** - Maps platform names to TMDB provider IDs
- **Caching system** - 24h for platform mappings, 10min for query results
- **Health monitoring** - Endpoints for monitoring and debugging

### 2. Flutter App Updates
- **ServerStreamingService** - New service for server communication
- **Updated MovieService** - Integrates server-side streaming filtering
- **Fallback mechanism** - Uses client-side filtering if server is unavailable

## Setup Instructions

### Step 1: Start the Server

```bash
cd movie_picker/server

# Install dependencies
npm install

# Copy environment template
cp env.example .env

# Edit .env and add your TMDB API key
# TMDB_API_KEY=your_tmdb_api_key_here

# Start the server
npm run dev
```

The server will start on `http://localhost:3001`

### Step 2: Test the Server

```bash
# Test server health
curl http://localhost:3001/health

# Test streaming filter
curl -X POST http://localhost:3001/filter/streaming \
  -H "Content-Type: application/json" \
  -d '{"platforms":["netflix"],"region":"US","type":"movie"}'
```

### Step 3: Update Your Flutter App

The Flutter app has been updated with the following changes:

#### New Service: `ServerStreamingService`
- Handles communication with the streaming filter server
- Provides caching for platform mappings and query results
- Includes fallback mechanisms for server unavailability

#### Updated `MovieService`
- Added streaming filter state management
- Integrated server-side streaming filtering
- Maintains backward compatibility with existing filters

## Usage Examples

### Basic Streaming Filter

```dart
// Enable streaming filter
movieService.setStreamingFilterEnabled(true);
movieService.setStreamingPlatforms(['netflix', 'amazon_prime']);
movieService.setStreamingRegion('US');

// Find movies with streaming filter
final movies = await movieService.findMoviesWithFilters(
  targetCount: 100,
);
```

### Multiple Platforms

```dart
// Filter for multiple streaming platforms
movieService.setStreamingPlatforms([
  'netflix',
  'amazon_prime', 
  'disney_plus',
  'hbo_max'
]);

final movies = await movieService.findMoviesWithFilters();
```

### Regional Filtering

```dart
// UK region with UK-specific platforms
movieService.setStreamingRegion('GB');
movieService.setStreamingPlatforms([
  'netflix',
  'bbc_iplayer',
  'itv_hub'
]);

final movies = await movieService.findMoviesWithFilters();
```

### Combined with Other Filters

```dart
// Combine streaming filter with other filters
movieService.setStreamingFilterEnabled(true);
movieService.setStreamingPlatforms(['netflix']);

final movies = await movieService.findMoviesWithFilters(
  selectedGenres: ['Action', 'Comedy'],
  language: 'en',
  timePeriod: '2020-2024',
  minRating: 7.0,
  targetCount: 100,
);
```

## API Reference

### ServerStreamingService Methods

```dart
// Get available platforms from server
Future<List<Map<String, dynamic>>> getAvailablePlatforms()

// Filter movies by streaming platforms
Future<List<Movie>> filterMoviesByStreamingPlatforms({
  required List<String> platforms,
  String region = 'US',
  String type = 'movie',
  int targetCount = 100,
})

// Check server health
Future<bool> checkServerHealth()

// Clear all caches
void clearCache()

// Get cache statistics
Map<String, dynamic> getCacheStats()
```

### MovieService Streaming Methods

```dart
// Enable/disable streaming filter
void setStreamingFilterEnabled(bool enabled)

// Set streaming platforms
void setStreamingPlatforms(List<String> platforms)

// Set streaming region
void setStreamingRegion(String region)

// Get streaming filter state
bool get streamingFilterEnabled
List<String>? get selectedStreamingPlatforms
String get streamingRegion

// Get available platforms from server
Future<List<Map<String, dynamic>>> getAvailableStreamingPlatforms()

// Check server health
Future<bool> checkStreamingServerHealth()
```

## Supported Platforms

### US Providers
- `netflix` (8)
- `amazon_prime` (9)
- `disney_plus` (2)
- `hbo_max` (384)
- `hulu` (15)
- `apple_tv` (350)
- `paramount_plus` (531)
- `peacock` (386)
- `crunchyroll` (283)

### UK Providers
- `bbc_iplayer` (318)
- `itv_hub` (319)
- `all4` (320)
- `my5` (321)
- `britbox` (322)
- `now_tv` (39)
- `sky_go` (29)
- `bt_tv` (323)
- `virgin_tv` (324)

### International Providers
- `canal_plus` (230) - France
- `m6` (231) - France
- `tf1` (232) - France
- `arte` (233) - France
- `rtl_plus` (234) - Germany
- `prosieben` (235) - Germany
- `zdf` (236) - Germany
- `mediaset` (237) - Italy
- `rai_play` (238) - Italy
- `movistar_plus` (149) - Spain
- `atresplayer` (240) - Spain

## Migration from Client-Side Filtering

### Before (Client-Side)
```dart
// Old client-side filtering (slow and inefficient)
final movies = await movieService.findMoviesWithFilters();
final streamingFiltered = await _filterMoviesByStreamingServices(movies);
```

### After (Server-Side)
```dart
// New server-side filtering (fast and efficient)
movieService.setStreamingFilterEnabled(true);
movieService.setStreamingPlatforms(['netflix', 'amazon_prime']);
final movies = await movieService.findMoviesWithFilters();
```

## Performance Benefits

1. **Eliminates redundant API calls** - No more individual `/movie/{id}/watch/providers` calls
2. **Server-side filtering** - Uses TMDB's `with_watch_providers` parameter directly
3. **Intelligent caching** - Reduces API calls and improves response times
4. **Regional accuracy** - Proper handling of regional availability differences
5. **Fallback support** - Graceful degradation if server is unavailable

## Monitoring and Debugging

### Server Logs
The server provides detailed logging:
```
🎬 Streaming filter request: {platforms: [netflix, amazon_prime], region: US, type: movie}
🔍 Provider IDs for platforms: [8, 9]
🌐 Making TMDB request to: https://api.themoviedb.org/3/discover/movie
✅ TMDB returned 20 results
💾 Cached results for key: streaming_movie_US_amazon_prime,netflix
```

### Flutter Debug Logs
The Flutter app provides debug information:
```
🎬 Using server-side streaming filter
🎬 Filtering movies by streaming platforms: netflix, amazon_prime
✅ Server returned 20 movies for streaming filter
```

### Health Monitoring
```bash
# Check server health
curl http://localhost:3001/health

# Get available platforms
curl http://localhost:3001/platforms

# Test streaming filter
curl -X POST http://localhost:3001/filter/streaming \
  -H "Content-Type: application/json" \
  -d '{"platforms":["netflix"],"region":"US","type":"movie"}'
```

## Troubleshooting

### Common Issues

1. **Server Not Starting**
   - Check if Node.js is installed
   - Verify TMDB API key is set in `.env`
   - Check if port 3001 is available

2. **Flutter App Can't Connect**
   - Ensure server is running on `http://localhost:3001`
   - Check network connectivity
   - Verify CORS configuration

3. **No Results from Streaming Filter**
   - Check if platform names are correct
   - Verify TMDB provider IDs are valid
   - Test with different regions

4. **Performance Issues**
   - Check server logs for errors
   - Verify caching is working
   - Monitor API rate limits

### Debug Commands

```bash
# Test server functionality
cd movie_picker/server
node test_server.js

# Check server health
curl http://localhost:3001/health

# Test streaming filter
curl -X POST http://localhost:3001/filter/streaming \
  -H "Content-Type: application/json" \
  -d '{"platforms":["netflix"],"region":"US","type":"movie"}'

# Clear cache (development only)
curl -X DELETE http://localhost:3001/cache
```

## Production Deployment

For production deployment:

1. **Server Setup**
   - Use a process manager (PM2, Docker, etc.)
   - Configure reverse proxy (nginx, Apache)
   - Set up monitoring and logging
   - Use environment variables for configuration

2. **Flutter App Updates**
   - Update server URL for production
   - Configure proper error handling
   - Implement retry mechanisms
   - Add user feedback for server issues

3. **Monitoring**
   - Set up health checks
   - Monitor API rate limits
   - Track performance metrics
   - Configure alerts for failures

## Next Steps

1. **Test the integration** - Use the provided test scripts
2. **Update your UI** - Modify streaming filter UI to use new methods
3. **Monitor performance** - Compare before/after performance metrics
4. **Deploy to production** - Follow production deployment guidelines
5. **Gather feedback** - Monitor user experience and performance

The server-side streaming filter provides significant performance improvements while maintaining full backward compatibility with your existing Flutter app. 