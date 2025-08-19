# Semantic Server Deployment

This directory contains the Node server for semantic search, images, and streaming endpoints.

Endpoints:
- GET /health
- GET /images/:movieId
- POST /filter/streaming
- POST /semantic/search
- POST /semantic/streaming

Env vars:
- OPENAI_API_KEY (required)
- TMDB_API_KEY (required)
- PORT (default 3001)

## Render (no Docker needed)
1. Push this repo to GitHub.
2. In Render, create a new Web Service from `movie_picker/server`.
   - Build Command: `npm ci --only=production`
   - Start Command: `node server.js`
   - Health Check Path: `/health`
3. Add env vars OPENAI_API_KEY and TMDB_API_KEY.
4. Deploy. Copy the service URL.

## Docker (any container host)
1. Build: `docker build -t moviemuse-semantic-server .`
2. Run: `docker run -e OPENAI_API_KEY=... -e TMDB_API_KEY=... -p 3001:3001 moviemuse-semantic-server`

## App configuration
Set `SEMANTIC_SERVER_URL` in the Flutter app `.env` to your deployed URL, e.g.
```
SEMANTIC_SERVER_URL=https://moviemuse-semantic.onrender.com
```
Restart the app. 