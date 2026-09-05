import express from 'express';
import http from 'http';
import cors from 'cors';
import { Server as SocketIOServer } from 'socket.io';
import { ENV } from './config/env';
import { authRouter } from './modules/auth/auth.controller';
import { subscriptionRouter } from './modules/subscriptions/subscription.controller';
import { rideRouter } from './modules/rides/ride.controller';
import { paymentRouter } from './modules/payments/payment.controller';
import { adminRouter } from './modules/admin/admin.controller';
import { kycRouter } from './modules/kyc/kyc.controller';
import { setupBiddingGateway } from './modules/bidding/bidding.gateway';

const app = express();
const server = http.createServer(app);

// Initialize Socket.io with permissive CORS for Flutter apps and Web dashboard
const io = new SocketIOServer(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Middlewares
app.use(cors());
app.use(express.json());

// Health Check
app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'online',
    platform: 'Giga Ride Platform',
    currency: 'NGN',
    model: 'Subscription-only (Zero Trip Commission)',
    timestamp: new Date().toISOString(),
  });
});

// REST API Routes
app.use('/api/auth', authRouter);
app.use('/api/subscriptions', subscriptionRouter);
app.use('/api/rides', rideRouter);
app.use('/api/payments', paymentRouter);
app.use('/api/admin', adminRouter);
app.use('/api/kyc', kycRouter);

// Initialize Socket.io Real-Time Bidding Gateway
setupBiddingGateway(io);

// Global Error Handler
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled server error:', err);
  res.status(500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

// Start Server
const PORT = ENV.PORT;
server.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(` 🚀 Giga Ride Platform Backend Running on port ${PORT}`);
  console.log(` 📍 Market: Nigeria (Lagos / Abuja / PH)`);
  console.log(` 💳 Zero Commission Bidding Engine Active`);
  console.log(` ⚡ Socket.io Real-Time Gateway Ready`);
  console.log(`====================================================`);
});
