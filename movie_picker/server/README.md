# Movie Picker Streaming Filter Server

This server provides server-side streaming filtering for the Movie Picker app, solving performance issues with client-side streaming filtering.

## Features

- **Server-side streaming filtering** using TMDB's `with_watch_providers` parameter
- **Platform name to TMDB provider ID mapping** (e.g., "Netflix" → 8)
- **Regional availability support** (US, UK, international providers)
- **Intelligent caching** (24h for platform mappings, 10min for query results)
- **Fallback to client-side filtering** if server is unavailable
- **Health monitoring** and cache management endpoints

## Setup

### 1. Install Dependencies

```bash
cd movie_picker/server
npm install
```

### 2. Configure Environment

Copy the environment template and add your TMDB API key:

```bash
cp env.example .env
```

Edit `.env` and add your TMDB API key:

```env
TMDB_API_KEY=your_tmdb_api_key_here
TMDB_BASE_URL=https://api.themoviedb.org/3
PORT=3001
NODE_ENV=development
PLATFORM_CACHE_TTL=86400
QUERY_CACHE_TTL=600
```

### 3. Start the Server

**Development mode (with auto-restart):**
```bash
npm run dev
```

**Production mode:**
```bash
npm start
```

The server will start on `http://localhost:3001`

## API Endpoints

### POST `/filter/streaming`
Main streaming filter endpoint.

**Request:**
```json
{
  "platforms": ["netflix", "amazon_prime"],
  "region": "US",
  "type": "movie"
}
```

**Response:**
```json
{
  "success": true,
  "cached": false,
  "data": [...],
  "count": 20,
  "query_info": {
    "platforms": ["netflix", "amazon_prime"],
    "region": "US",
    "type": "movie",
    "provider_ids": [8, 9],
    "cache_key": "streaming_movie_US_amazon_prime,netflix"
  }
}
```

### GET `/platforms`
Get available streaming platforms.

**Response:**
```json
{
  "success": true,
  "platforms": [
    {
      "id": "netflix",
      "name": "Netflix",
      "provider_id": 8
    }
  ],
  "count": 25
}
```

### GET `/health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "cache_stats": {
    "platform_cache_size": 0,
    "query_cache_size": 5
  }
}
```

### DELETE `/cache`
Clear all caches (development only).

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

## Integration with Flutter App

The Flutter app has been updated to use this server for streaming filtering:

1. **ServerStreamingService** - Handles communication with the server
2. **Updated MovieService** - Integrates server-side streaming filtering
3. **Fallback mechanism** - Uses client-side filtering if server is unavailable

### Usage in Flutter

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

## Performance Benefits

1. **Eliminates redundant API calls** - No more individual `/movie/{id}/watch/providers` calls
2. **Server-side filtering** - Uses TMDB's `with_watch_providers` parameter directly
3. **Intelligent caching** - Reduces API calls and improves response times
4. **Regional accuracy** - Proper handling of regional availability differences
5. **Fallback support** - Graceful degradation if server is unavailable

## Monitoring

The server provides detailed logging:

```
🎬 Streaming filter request: {platforms: [netflix, amazon_prime], region: US, type: movie}
🔍 Provider IDs for platforms: [8, 9]
🌐 Making TMDB request to: https://api.themoviedb.org/3/discover/movie
✅ TMDB returned 20 results
💾 Cached results for key: streaming_movie_US_amazon_prime,netflix
```

## Deployment

For production deployment:

1. Set `NODE_ENV=production`
2. Use a proper process manager (PM2, Docker, etc.)
3. Configure reverse proxy (nginx, Apache)
4. Set up monitoring and logging
5. Use environment variables for configuration

## Troubleshooting

### Common Issues

1. **TMDB API Key Missing**
   - Ensure `TMDB_API_KEY` is set in `.env`

2. **Server Not Starting**
   - Check if port 3001 is available
   - Verify all dependencies are installed

3. **No Results from Streaming Filter**
   - Check if platform names are correct
   - Verify TMDB provider IDs are valid
   - Test with different regions

4. **Flutter App Can't Connect**
   - Ensure server is running on `http://localhost:3001`
   - Check CORS configuration
   - Verify network connectivity

### Debug Commands

```bash
# Test server health
curl http://localhost:3001/health

# Test streaming filter
curl -X POST http://localhost:3001/filter/streaming \
  -H "Content-Type: application/json" \
  -d '{"platforms":["netflix"],"region":"US","type":"movie"}'

# Get available platforms
curl http://localhost:3001/platforms

# Clear cache (development only)
curl -X DELETE http://localhost:3001/cache
``` 