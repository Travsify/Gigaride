const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;

// ─────────────────────────────────────────────────────────────────────────────
// REVERSE PROXY: Forward all /api/*, /socket.io/*, and /health requests to the
// backend running on localhost:4000.
// We use pathFilter directly in createProxyMiddleware so Express does NOT strip
// the '/api' prefix from req.url.
// ─────────────────────────────────────────────────────────────────────────────
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:4000';

app.use(
  createProxyMiddleware({
    target: BACKEND_URL,
    changeOrigin: true,
    ws: true,
    pathFilter: ['/api', '/socket.io', '/health'],
    on: {
      error: (err, req, res) => {
        console.error('[Proxy Error]', err.message);
        if (res && !res.headersSent) {
          res.status(502).json({ success: false, message: 'Backend gateway unavailable. Please try again shortly.' });
        }
      },
    },
  })
);

app.disable('etag');

// Global cache-busting middleware to ensure clients always get the freshest dashboard code
app.use((req, res, next) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.setHeader('Surrogate-Control', 'no-store');
  next();
});

// ─────────────────────────────────────────────────────────────────────────────
// STATIC ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
app.use(express.static(path.join(__dirname, 'public'), {
  etag: false,
  maxAge: 0,
  setHeaders: (res) => {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }
}));

app.get('*', (req, res) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`✅ Giga Ride Admin Console running at http://localhost:${PORT}`);
  console.log(`   API proxied → ${BACKEND_URL}`);
});
