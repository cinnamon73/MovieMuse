// Set environment variables
process.env.TMDB_API_KEY = 'f26e4183a1a1ea7149cfb88dd01979bb';
process.env.TMDB_BASE_URL = 'https://api.themoviedb.org/3';
process.env.PORT = '3001';
process.env.NODE_ENV = 'development';

console.log('🚀 Starting streaming filter server...');
console.log(`📡 TMDB API Key: ${process.env.TMDB_API_KEY ? '✅ Configured' : '❌ Missing'}`);
console.log(`🌐 Port: ${process.env.PORT}`);

// Start the server
require('./server.js'); 