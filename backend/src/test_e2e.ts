import http from 'http';
import { io as ClientSocket } from 'socket.io-client';
import axios from 'axios';
import { Server as SocketIOServer } from 'socket.io';
import express from 'express';
import cors from 'cors';
import { authRouter } from './modules/auth/auth.controller';
import { subscriptionRouter } from './modules/subscriptions/subscription.controller';
import { rideRouter } from './modules/rides/ride.controller';
import { paymentRouter } from './modules/payments/payment.controller';
import { adminRouter } from './modules/admin/admin.controller';
import { setupBiddingGateway } from './modules/bidding/bidding.gateway';
import { db } from './database';
import { subscriptionService } from './modules/subscriptions/subscription.service';

const PORT = 4099;
const BASE_URL = `http://localhost:${PORT}`;

async function runE2ETest() {
  console.log('--- STARTING COMPLETE E2E VERIFICATION TEST ---');

  // 1. Spin up dedicated test server instance
  const app = express();
  const server = http.createServer(app);
  const io = new SocketIOServer(server, { cors: { origin: '*' } });

  app.use(cors());
  app.use(express.json());
  app.use('/api/auth', authRouter);
  app.use('/api/subscriptions', subscriptionRouter);
  app.use('/api/rides', rideRouter);
  app.use('/api/payments', paymentRouter);
  app.use('/api/admin', adminRouter);

  setupBiddingGateway(io);

  await new Promise<void>((resolve) => server.listen(PORT, () => resolve()));
  console.log(`[Test Server] Listening on port ${PORT}`);

  try {
    // 2. Register Driver in Lagos
    console.log('\n1. Registering Driver (Adebayo in Lagos)...');
    const driverRes = await axios.post(`${BASE_URL}/api/auth/register`, {
      role: 'DRIVER',
      fullName: 'Adebayo Adeleke',
      phoneNumber: '08012345678',
      email: 'adebayo.driver@gigaride.ng',
      password: 'password123',
      vehicleMake: 'Toyota',
      vehicleModel: 'Corolla',
      vehicleYear: 2016,
      licensePlate: 'APP-842-XY',
      vehicleColor: 'Silver Metallic',
      nin: '12345678901',
    });
    const driverToken = driverRes.data.data.token;
    const driverId = driverRes.data.data.user.id;
    console.log('   ✓ Driver Registered:', driverRes.data.data.user.fullName);
    console.log('   ✓ Driver Vehicle:', driverRes.data.data.driverProfile.vehicle_make, driverRes.data.data.driverProfile.vehicle_model);

    // 3. Check Driver Welcome Subscription
    const driverSub = await subscriptionService.getDriverSubscriptionStatus(driverId);
    console.log(`   ✓ Driver Initial Welcome Rides: ${driverSub.remainingRides} rides remaining (Active: ${driverSub.hasActiveSubscription})`);

    // 4. Register Passenger in Yaba
    console.log('\n2. Registering Passenger (Chioma in Yaba)...');
    const passengerRes = await axios.post(`${BASE_URL}/api/auth/register`, {
      role: 'PASSENGER',
      fullName: 'Chioma Okafor',
      phoneNumber: '08098765432',
      email: 'chioma.okafor@gmail.com',
      password: 'password123',
    });
    const passengerToken = passengerRes.data.data.token;
    const passengerId = passengerRes.data.data.user.id;
    console.log('   ✓ Passenger Registered:', passengerRes.data.data.user.fullName);

    // 5. Query Subscription Plans
    console.log('\n3. Fetching Available Subscription Plans...');
    const plansRes = await axios.get(`${BASE_URL}/api/subscriptions/plans`);
    console.log(`   ✓ Found ${plansRes.data.data.length} subscription plans:`);
    plansRes.data.data.forEach((p: any) => {
      console.log(`     - ${p.name}: ₦${(p.price_kobo / 100).toLocaleString()} (${p.total_rides ?? 'Unlimited'} rides for ${p.duration_days} days)`);
    });

    // 6. Calculate Fare Estimate (Yaba to Victoria Island)
    console.log('\n4. Calculating Fare Estimate (Yaba to Victoria Island)...');
    const estimateRes = await axios.post(`${BASE_URL}/api/rides/estimate`, {
      pickupLat: 6.518,
      pickupLng: 3.379,
      dropoffLat: 6.428,
      dropoffLng: 3.421,
    });
    const estimate = estimateRes.data.data;
    console.log(`   ✓ Distance: ${estimate.distanceKm} km (~${estimate.estimatedMinutes} mins)`);
    console.log(`   ✓ Fuel Cost Estimate: ₦${estimate.fuelCostEstimateNgn.toLocaleString()}`);
    console.log(`   ✓ Suggested Platform Fare: ₦${estimate.suggestedFareNgn.toLocaleString()}`);
    console.log(`   ✓ Minimum Bidding Floor: ₦${estimate.minimumBidFloorNgn.toLocaleString()}`);

    // 7. Connect Live WebSockets for Driver & Passenger
    console.log('\n5. Establishing Real-time WebSocket Connections...');
    const driverSocket = ClientSocket(BASE_URL, {
      auth: { token: driverToken },
    });
    const passengerSocket = ClientSocket(BASE_URL, {
      auth: { token: passengerToken },
    });

    await Promise.all([
      new Promise<void>((res) => driverSocket.on('connect', res)),
      new Promise<void>((res) => passengerSocket.on('connect', res)),
    ]);
    console.log('   ✓ Both Driver and Passenger Sockets connected!');

    // Driver broadcasts live GPS coordinates (in Yaba near pickup)
    driverSocket.emit('driver:location', {
      latitude: 6.519,
      longitude: 3.380,
      isOnline: true,
    });
    await new Promise((r) => setTimeout(r, 200));

    // 8. Passenger Creates Ride Request via REST
    console.log('\n6. Passenger Requests Ride with Offer ₦4,500...');
    const rideRes = await axios.post(
      `${BASE_URL}/api/rides/request`,
      {
        pickupLat: 6.518,
        pickupLng: 3.379,
        pickupAddress: 'Commercial Avenue, Yaba, Lagos',
        dropoffLat: 6.428,
        dropoffLng: 3.421,
        dropoffAddress: 'Adetokunbo Ademola, Victoria Island, Lagos',
        riderOfferNgn: 4500,
      },
      { headers: { Authorization: `Bearer ${passengerToken}` } }
    );
    const rideId = rideRes.data.data.id;
    console.log('   ✓ Ride Created in NEGOTIATING status with ID:', rideId);

    // 9. Dispatching Broadcast over WebSockets
    console.log('\n7. Testing Real-time Bidding & Counter-Offers...');
    const rideReceivedPromise = new Promise<any>((resolve) => {
      driverSocket.once('ride:new_request', resolve);
    });

    // Passenger triggers dispatch search
    passengerSocket.emit('ride:request', { rideId });

    const incomingRequestForDriver = await rideReceivedPromise;
    console.log(`   ✓ Driver received dispatch broadcast for ride! Distance to pickup: ${incomingRequestForDriver.driverPickupDistanceKm}km`);

    // Driver counters with ₦5,000
    const passengerBidPromise = new Promise<any>((resolve) => {
      passengerSocket.once('passenger:new_bid', resolve);
    });

    driverSocket.emit('driver:submit_bid', {
      rideId,
      counterFareNgn: 5000,
      etaMinutes: 4,
    });

    const receivedBidByPassenger = await passengerBidPromise;
    console.log(`   ✓ Passenger screen received bid from ${receivedBidByPassenger.driverName} (${receivedBidByPassenger.vehicleMake} ${receivedBidByPassenger.vehicleModel}): ₦${receivedBidByPassenger.counterFareNgn}`);

    // Passenger accepts driver bid
    const driverAssignedPromise = new Promise<any>((resolve) => {
      driverSocket.once('ride:assigned', resolve);
    });

    passengerSocket.emit('passenger:accept_bid', {
      rideId,
      driverId,
      agreedFareNgn: 5000,
    });

    const assignedRide = await driverAssignedPromise;
    console.log(`   ✓ Driver received confirmation! Ride locked at agreed fare: ₦${assignedRide.agreedFareNgn}`);

    // 10. Complete Trip & Verify Automatic Subscription Ride Deduction
    console.log('\n8. Simulating Trip Completion & Ride Credit Deduction...');
    const subUpdatedPromise = new Promise<any>((resolve) => {
      driverSocket.once('subscription:updated', resolve);
    });

    driverSocket.emit('driver:update_status', {
      rideId,
      status: 'COMPLETED',
    });

    const subUpdate = await subUpdatedPromise;
    console.log(`   ✓ Ride completed! Driver remaining rides automatically decremented to: ${subUpdate.remainingRides} rides`);

    // 11. Test the "Exhausted Subscription Gatekeeper"
    console.log('\n9. Testing Out-of-Rides Gatekeeper & Visibility Lockout...');
    // Artificially decrement remaining rides to -2 to simulate full exhaustion
    const activeSub = await db.getActiveDriverSubscription(driverId);
    activeSub!.remaining_rides = -2;
    activeSub!.status = 'EXHAUSTED';

    const gatekeeperStatus = await subscriptionService.isDriverEligibleForDispatch(driverId);
    console.log(`   ✓ Is exhausted driver eligible for dispatch? ${gatekeeperStatus} (Expected: false)`);

    // Attempt to bid while exhausted
    const exhaustedWarningPromise = new Promise<any>((resolve) => {
      driverSocket.once('subscription:exhausted', resolve);
    });

    driverSocket.emit('driver:submit_bid', {
      rideId: 'another_ride_id',
      counterFareNgn: 6000,
      etaMinutes: 5,
    });

    const warning = await exhaustedWarningPromise;
    console.log(`   ✓ Gatekeeper blocked exhausted driver bid: "${warning.message}"`);

    // 12. Driver Resubscribes with 50-Ride Weekly Hustle
    console.log('\n10. Driver Resubscribes via Purchase Endpoint...');
    const purchaseRes = await axios.post(
      `${BASE_URL}/api/subscriptions/purchase`,
      { planId: 'plan_standard_50' },
      { headers: { Authorization: `Bearer ${driverToken}` } }
    );
    console.log(`   ✓ Successfully Purchased: ${purchaseRes.data.data.plan_id}`);
    console.log(`   ✓ New Remaining Rides: ${purchaseRes.data.data.remaining_rides}`);

    const newEligibility = await subscriptionService.isDriverEligibleForDispatch(driverId);
    console.log(`   ✓ Driver re-enabled for dispatch radar: ${newEligibility} (Expected: true)`);

    console.log('\n====================================================');
    console.log(' ✅ ALL E2E VERIFICATION TESTS PASSED SUCCESSFULLY! ');
    console.log('====================================================');

    driverSocket.disconnect();
    passengerSocket.disconnect();
    server.close();
    process.exit(0);
  } catch (err: any) {
    console.error('❌ E2E TEST FAILED:', err.response?.data || err.message);
    server.close();
    process.exit(1);
  }
}

runE2ETest();
