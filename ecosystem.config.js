module.exports = {
  apps: [
    {
      name: 'giga-backend',
      cwd: '/var/www/giga/backend',
      script: 'dist/index.js',
      env: {
        PORT: 4001,
        NODE_ENV: 'production'
      }
    },
    {
      name: 'giga-admin',
      cwd: '/var/www/giga/admin_dashboard',
      script: 'server.js',
      env: {
        PORT: 3001,
        BACKEND_URL: 'http://127.0.0.1:4001',
        NODE_ENV: 'production'
      }
    }
  ]
};
