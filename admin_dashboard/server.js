const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;

// ─────────────────────────────────────────────────────────────────────────────
// REVERSE PROXY: Forward all /api/* and /socket.io/* requests to the backend
// running on localhost:4000.  This means the browser only ever needs to reach
// port 3000 — the server handles the tunnel to port 4000 internally.
// ─────────────────────────────────────────────────────────────────────────────
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:4000';

app.use(
  '/api',
  createProxyMiddleware({
    target: BACKEND_URL,
    changeOrigin: true,
    ws: false,
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

app.use(
  '/socket.io',
  createProxyMiddleware({
    target: BACKEND_URL,
    changeOrigin: true,
    ws: true,
  })
);

// ─────────────────────────────────────────────────────────────────────────────
// STATIC ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
app.use(express.static(path.join(__dirname, 'public')));

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`✅ Giga Ride Admin Console running at http://localhost:${PORT}`);
  console.log(`   API proxied → ${BACKEND_URL}`);
});
