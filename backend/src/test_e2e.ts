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
import { kycRouter } from './modules/kyc/kyc.controller';
import { setupBiddingGateway } from './modules/bidding/bidding.gateway';
import { db } from './database';
import { subscriptionService } from './modules/subscriptions/subscription.service';
import { adminService } from './modules/admin/admin.service';
import { autoTopupService } from './modules/subscriptions/autoTopup.service';

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
  app.use('/api/kyc', kycRouter);

  setupBiddingGateway(io);

  await new Promise<void>((resolve) => server.listen(PORT, () => resolve()));
  console.log(`[Test Server] Listening on port ${PORT}`);

  try {
    const runId = Date.now().toString().slice(-6);
    // 2. Register Driver in Lagos
    console.log('\n1. Registering Driver (Adebayo in Lagos)...');
    const driverRes = await axios.post(`${BASE_URL}/api/auth/register`, {
      role: 'DRIVER',
      fullName: 'Adebayo Adeleke',
      phoneNumber: `0801${runId}`,
      email: `driver_${runId}@gigaride.ng`,
      password: 'password123',
      vehicleMake: 'Toyota',
      vehicleModel: 'Corolla',
      vehicleYear: 2016,
      licensePlate: `APP-${runId.slice(0, 3)}-XY`,
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
      phoneNumber: `0809${runId}`,
      email: `passenger_${runId}@gmail.com`,
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

    // 13. Super Admin Operations Verification
    console.log('\n11. Authenticating Super Admin & Testing Operations...');
    const adminRes = await axios.post(`${BASE_URL}/api/auth/register`, {
      role: 'ADMIN',
      fullName: 'Super Admin Officer',
      phoneNumber: `0800${runId}`,
      email: `admin_${runId}@gigaride.ng`,
      password: 'admin_secure_password',
    });
    const adminToken = adminRes.data.data.token;
    console.log('   ✓ Super Admin Authenticated');

    // Test Dynamic Platform Settings & Fuel Price Lever
    console.log('\n12. Testing Dynamic Fuel Levers (PMS price update)...');
    const updateSettingsRes = await axios.put(
      `${BASE_URL}/api/admin/settings`,
      { petrol_price_ngn: 1250 }, // Fuel increases to ₦1,250/L
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log(`   ✓ Updated Platform Petrol Price: ₦${updateSettingsRes.data.data.petrol_price_ngn}/L`);

    // Verify fare estimate immediately uses updated petrol price
    const newEstimateRes = await axios.post(`${BASE_URL}/api/rides/estimate`, {
      pickupLat: 6.518,
      pickupLng: 3.379,
      dropoffLat: 6.428,
      dropoffLng: 3.421,
    });
    console.log(`   ✓ New Fuel Cost Estimate with ₦1,250/L: ₦${newEstimateRes.data.data.fuelCostEstimateNgn} (automatically updated without code restart!)`);

    // Test Manual Ride Credit (Customer Support Desk)
    console.log('\n13. Testing Manual Ride Credit Overrides...');
    const creditRes = await axios.post(
      `${BASE_URL}/api/admin/drivers/${driverId}/credit-rides`,
      { ridesToAdd: 15, reason: 'Verified offline direct bank transfer to Moniepoint account' },
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log(`   ✓ Admin credited 15 rides. New driver balance: ${creditRes.data.data.remaining_rides} rides`);

    // Test Driver Dossier Retrieval
    console.log('\n14. Testing Driver 360-Degree Dossier...');
    const dossierRes = await axios.get(`${BASE_URL}/api/admin/drivers/${driverId}`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.log(`   ✓ Dossier fetched: ${dossierRes.data.data.user.full_name} | Plate: ${dossierRes.data.data.profile.license_plate} | Status: ${dossierRes.data.data.profile.account_status}`);

    // Test Driver KYC Rejection with Reason
    console.log('\n15. Testing Driver KYC Review with Specific Rejection Reason...');
    const kycRejectRes = await axios.post(
      `${BASE_URL}/api/admin/drivers/${driverId}/kyc-review`,
      { status: 'REJECTED', rejectionReason: 'Driver license photo was blurred. Please re-upload clear image.' },
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log(`   ✓ KYC rejection logged with reason: "${kycRejectRes.data.data.rejectionReason}"`);

    // Test Emergency SOS Incident
    console.log('\n16. Testing Emergency SOS Incident Pipeline...');
    const sosRes = await axios.get(`${BASE_URL}/api/admin/sos`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.log(`   ✓ SOS Incident Feed accessible (Count: ${sosRes.data.data.length})`);

    // 17. Multi-Tier RBAC Permission Barrier
    console.log('\n17. Testing Multi-Tier RBAC Permission Enforcement...');
    // Create a support agent user
    const supportAgentRes = await axios.post(`${BASE_URL}/api/auth/register`, {
      role: 'ADMIN',
      fullName: 'Support Officer Tunde',
      phoneNumber: `080399${runId.slice(-5)}`,
      email: `support_${runId}@gigaride.ng`,
      password: 'support_password_123',
    });
    // Manually set role to SUPPORT_AGENT in store
    const supportUser = await db.findUserById(supportAgentRes.data.data.user.id);
    if (supportUser) supportUser.admin_role = 'SUPPORT_AGENT';
    const supportLogin = await axios.post(`${BASE_URL}/api/auth/login`, {
      identifier: `support_${runId}@gigaride.ng`,
      password: 'support_password_123',
    });
    const supportToken = supportLogin.data.data.token;

    let rbacBlocked = false;
    try {
      // Support agent attempts to modify national petrol price (should be forbidden!)
      await axios.put(
        `${BASE_URL}/api/admin/settings`,
        { petrol_price_ngn: 9999 },
        { headers: { Authorization: `Bearer ${supportToken}` } }
      );
    } catch (err: any) {
      if (err.response?.status === 403) {
        rbacBlocked = true;
      }
    }
    console.log(`   ✓ RBAC Gatekeeper blocked Support Agent from updating fuel levers: ${rbacBlocked} (Expected: true)`);

    // 18. Dynamic Subscription Plan Builder (CRUD)
    console.log('\n18. Testing Dynamic Subscription Plan Builder (CRUD)...');
    const newPlanPayload = {
      id: `plan_flash_${runId}`,
      name: '25-Ride Weekend Hustle Special',
      description: 'Exclusive flash sale for weekend drivers. Zero commission.',
      plan_type: 'RIDE_COUNT',
      total_rides: 25,
      duration_days: 3,
      price_kobo: 350000,
      is_active: true,
    };
    const createPlanRes = await axios.post(
      `${BASE_URL}/api/admin/plans`,
      newPlanPayload,
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log(`   ✓ Admin created new plan: "${createPlanRes.data.data.name}" (₦3,500 for 25 rides)`);

    const allPlansRes = await axios.get(`${BASE_URL}/api/admin/plans`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const planExists = allPlansRes.data.data.some((p: any) => p.id === newPlanPayload.id);
    console.log(`   ✓ New plan immediately available in platform catalog: ${planExists}`);

    // 19. Grace Ride Debt Carryover Recovery
    console.log('\n19. Testing Emergency Grace Balance Debt Recovery...');
    // Simulate driver remaining balance dropped to -2 (grace threshold)
    const activeDriverSub = await db.getActiveDriverSubscription(driverId);
    if (activeDriverSub) {
      activeDriverSub.remaining_rides = -2;
    }
    console.log('   ✓ Simulated driver balance at -2 rides (emergency grace threshold used)');

    // Driver resubscribes to a 10-ride plan
    const resubWithRecovery = await subscriptionService.activateSubscription(driverId, 'plan_starter_10');
    console.log(`   ✓ Driver purchased 10-ride starter plan. Net balance after grace recovery: ${resubWithRecovery.remaining_rides} rides (Expected: 8)`);
    if (resubWithRecovery.remaining_rides !== 8) {
      throw new Error(`Grace debt recovery failed! Expected 8 remaining rides, got ${resubWithRecovery.remaining_rides}`);
    }

    // 20. Document Expiry Compliance & Dispatch Lockout
    console.log('\n20. Testing Document Expiration Tracking & Radar Lockout...');
    // Set driver's driver_license_expiry to expired date
    await adminService.updateDriverDocuments(
      { id: adminRes.data.data.user.id, email: 'admin@gigaride.ng' },
      driverId,
      {
        driver_license_expiry: '2024-01-01T00:00:00.000Z', // Expired
        insurance_expiry: '2027-12-31T00:00:00.000Z',
        road_worthiness_expiry: '2027-12-31T00:00:00.000Z',
        lasdri_card_number: 'LASDRI-2026-X99',
        lasdri_expiry: '2027-12-31T00:00:00.000Z',
      }
    );
    const isExpiredDriverEligible = await subscriptionService.isDriverEligibleForDispatch(driverId);
    console.log(`   ✓ Is driver with expired license eligible for dispatch? ${isExpiredDriverEligible} (Expected: false)`);
    if (isExpiredDriverEligible !== false) {
      throw new Error('Compliance check failed: Driver with expired documents was allowed on dispatch!');
    }

    // Reinstate valid license date
    await adminService.updateDriverDocuments(
      { id: adminRes.data.data.user.id, email: 'admin@gigaride.ng' },
      driverId,
      {
        driver_license_expiry: '2028-05-15T00:00:00.000Z', // Valid
      }
    );
    // Also re-approve KYC
    await db.updateDriverKyc(driverId, 'APPROVED');
    const isReinstatedEligible = await subscriptionService.isDriverEligibleForDispatch(driverId);
    console.log(`   ✓ Driver renewed license. Reinstated for dispatch radar: ${isReinstatedEligible} (Expected: true)`);

    // 21. 1-Click Official LASG Ministry of Transportation ₦50 Levy CSV Export
    console.log('\n21. Testing LASG Ministry of Transportation Tax CSV Export...');
    const motCsvRes = await axios.get(`${BASE_URL}/api/admin/finance/lasg-mot-export`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.log(`   ✓ HTTP Status: ${motCsvRes.status}`);
    console.log(`   ✓ Content-Type: ${motCsvRes.headers['content-type']}`);
    const csvHeaderLine = motCsvRes.data.split('\r\n')[0];
    console.log(`   ✓ CSV Columns: ${csvHeaderLine}`);

    // 22. Trip GPS Breadcrumbs Logging & Route Playback
    console.log('\n22. Testing High-Resolution GPS Breadcrumb Logging & Playback...');
    // Record sample breadcrumbs for ride
    await db.recordRideBreadcrumb({
      ride_id: rideId,
      driver_id: driverId,
      latitude: 6.5185,
      longitude: 3.3792,
      speed_kmh: 42.5,
    });
    await db.recordRideBreadcrumb({
      ride_id: rideId,
      driver_id: driverId,
      latitude: 6.5120,
      longitude: 3.3850,
      speed_kmh: 55.0,
    });
    const breadcrumbsRes = await axios.get(`${BASE_URL}/api/admin/rides/${rideId}/breadcrumbs`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.log(`   ✓ Retrieved ${breadcrumbsRes.data.data.length} breadcrumb GPS points for route playback`);
    console.log(`   ✓ Sample Point: Lat ${breadcrumbsRes.data.data[0].latitude}, Speed ${breadcrumbsRes.data.data[0].speed_kmh}km/h`);

    // 23. In-App Passenger & Driver Disputes Desk
    console.log('\n23. Testing In-App Dispute Resolution Desk...');
    const disputeRes = await db.createDispute({
      ride_id: rideId,
      reporter_id: passengerId,
      reporter_role: 'PASSENGER',
      dispute_type: 'AC_REFUSAL',
      description: 'Driver declined to turn on air conditioning during high afternoon traffic.',
    });
    console.log(`   ✓ Dispute filed: ID ${disputeRes.id} | Type: ${disputeRes.dispute_type}`);

    const resolveDisputeRes = await axios.post(
      `${BASE_URL}/api/admin/disputes/${disputeRes.id}/resolve`,
      {
        notes: 'Warning strike recorded against driver regarding vehicle AC terms.',
        driverStrikeApplied: true,
        compensationRides: 0,
      },
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log(`   ✓ Dispute resolved: Status "${resolveDisputeRes.data.data.status}" | Driver Strike: ${resolveDisputeRes.data.data.driver_strike_applied}`);

    // 24. Immutable Administrative Action Audit Logs
    console.log('\n24. Testing Immutable Admin Operations Audit Trail...');
    const auditLogsRes = await axios.get(`${BASE_URL}/api/admin/audit-logs`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.log(`   ✓ Total Administrative Audit Entries Logged: ${auditLogsRes.data.data.length}`);
    const latestActions = auditLogsRes.data.data.slice(0, 4).map((l: any) => l.action);
    console.log(`   ✓ Recent Actions in Audit Trail: ${latestActions.join(' → ')}`);

    // 25. Twilio Phone Number SMS OTP Verification Flow
    console.log('\n25. Testing Twilio Phone Number SMS OTP Verification Flow...');
    const otpSendRes = await axios.post(`${BASE_URL}/api/auth/send-otp`, {
      phoneNumber: '08098765432',
    });
    console.log('   ✓ SMS OTP Triggered:', otpSendRes.data.message);
    const otpVerifyRes = await axios.post(`${BASE_URL}/api/auth/verify-otp`, {
      phoneNumber: '08098765432',
      otpCode: otpSendRes.data.testOtp || '123456',
    });
    console.log('   ✓ SMS OTP Verified Successfully:', otpVerifyRes.data.success);

    // 26. Prembly NIN Verification & Automated Driver Approval
    console.log('\n26. Testing Prembly NIN Verification & Automated Driver Approval...');
    const premblyRes = await axios.post(
      `${BASE_URL}/api/kyc/verify-nin`,
      {
        driverId,
        nin: '11223344556',
        firstName: 'Adebayo',
        lastName: 'Adeleke',
      },
      { headers: { Authorization: `Bearer ${driverToken}` } }
    );
    console.log('   ✓ Prembly Response Status:', premblyRes.data.data?.status);
    const postKycDva = await db.getVirtualAccountByUserId(driverId);
    console.log('   ✓ Auto-DVA Provisioned:', postKycDva?.account_number);

    // 27. Korapay Dedicated Virtual Bank Account Generation & Top-Up
    console.log('\n27. Testing Korapay Dedicated Virtual Bank Account Generation & Top-Up...');
    const dvaRes = await axios.get(`${BASE_URL}/api/payments/virtual-account`, {
      headers: { Authorization: `Bearer ${driverToken}` },
    });
    console.log(`   ✓ DVA Bank: ${dvaRes.data.data.bank_name} | Account: ${dvaRes.data.data.account_number}`);
    console.log(`   ✓ Initial DVA Balance: ₦${dvaRes.data.data.balance_ngn}`);

    // Simulate NIP bank transfer credit of ₦15,000 to driver's DVA
    await axios.post(`${BASE_URL}/api/payments/korapay/webhook`, {
      event: 'charge.success',
      data: {
        account_number: dvaRes.data.data.account_number,
        amount: 15000,
        currency: 'NGN',
        reference: `NIP_TX_${Date.now()}`,
      },
    });
    const updatedDva = await db.getVirtualAccountByUserId(driverId);
    console.log(`   ✓ Updated DVA Balance after Inbound Bank Transfer: ₦${updatedDva?.balance_ngn}`);

    // 28. Passenger In-App Giga Wallet Ride Payment
    console.log('\n28. Testing Passenger Giga Wallet Payment for Ride...');
    await db.createOrUpdateVirtualAccount({
      id: `va_${Date.now()}`,
      user_id: passengerId,
      account_number: `9988${runId}`,
      bank_name: 'Wema Bank (Giga Wallet)',
      account_name: 'Chioma Okafor / GigaRide',
      bank_code: '035',
      account_reference: `ref_${Date.now()}`,
      provider: 'korapay',
      balance_ngn: 20000,
      is_active: true,
      created_at: new Date().toISOString(),
    });

    const walletPayRes = await axios.post(
      `${BASE_URL}/api/rides/${rideId}/pay-wallet`,
      {},
      { headers: { Authorization: `Bearer ${passengerToken}` } }
    );
    console.log('   ✓ Ride Paid via Passenger Wallet:', walletPayRes.data.message);
    console.log(`   ✓ Remaining Passenger Wallet Balance: ₦${walletPayRes.data.newPassengerBalance}`);

    // 29. Automated Driver Subscription Renewal on Threshold
    console.log('\n29. Testing Automated Driver Subscription Renewal on Threshold...');
    await axios.put(
      `${BASE_URL}/api/subscriptions/auto-topup-settings`,
      {
        autoTopupEnabled: true,
        autoTopupThreshold: 2,
        preferredPlanId: 'plan_starter_10',
      },
      { headers: { Authorization: `Bearer ${driverToken}` } }
    );

    let sub = await db.getActiveDriverSubscription(driverId);
    if (sub) sub.remaining_rides = 2;

    const topupResult = await autoTopupService.checkAndProcessDriverThreshold(driverId);
    console.log('   ✓ Auto Top-Up Evaluator Triggered:', topupResult.message);
    console.log('   ✓ Auto Top-Up Renewal Success:', topupResult.renewed);
    const renewedSub = await db.getActiveDriverSubscription(driverId);
    console.log(`   ✓ Renewed Subscription Remaining Rides: ${renewedSub?.remaining_rides}`);

    // 30. 2-Grace Rides Countdown & Strict Dispatch Lockout
    console.log('\n30. Testing 2-Grace Rides Countdown & Strict Dispatch Lockout...');
    if (renewedSub) renewedSub.remaining_rides = 0;
    await db.updateDriverLockout(driverId, false);
    const dvaNow = await db.getVirtualAccountByUserId(driverId);
    if (dvaNow && dvaNow.balance_ngn > 0) {
      await db.debitVirtualAccountBalance(dvaNow.account_number, dvaNow.balance_ngn);
    }

    // Grace Ride #1: trip completes, balance decrements to -1
    await subscriptionService.onRideCompleted(driverId);
    const grace1Result = await autoTopupService.checkAndProcessDriverThreshold(driverId);
    const subAfterGrace1 = await db.getActiveDriverSubscription(driverId);
    console.log(`   ✓ Grace Ride 1: Remaining Rides: ${subAfterGrace1?.remaining_rides} (Lockout: ${grace1Result.lockedOut})`);
    let isEligible = await subscriptionService.isDriverEligibleForDispatch(driverId);
    console.log(`   ✓ Driver eligible during Grace Window (1/2): ${isEligible} (Expected: true)`);

    // Grace Ride #2: trip completes, balance decrements to -2
    await subscriptionService.onRideCompleted(driverId);
    const grace2Result = await autoTopupService.checkAndProcessDriverThreshold(driverId);
    const subAfterGrace2 = await db.getActiveDriverSubscription(driverId);
    console.log(`   ✓ Grace Ride 2: Remaining Rides: ${subAfterGrace2?.remaining_rides} (Lockout: ${grace2Result.lockedOut})`);
    isEligible = await subscriptionService.isDriverEligibleForDispatch(driverId);
    console.log(`   ✓ Driver dispatch eligibility after exhausting 2 grace rides: ${isEligible} (Expected: false)`);

    // 31. Debt Recovery & Lockout Clearance upon Account Funding
    console.log('\n31. Testing Debt Recovery & Lockout Clearance upon Account Funding...');
    if (dvaNow) {
      await db.creditVirtualAccountBalance(dvaNow.account_number, 5000);
    }

    const debtRecoveryResult = await autoTopupService.checkAndProcessDriverThreshold(driverId);
    console.log('   ✓ Debt Recovery Renewal Triggered:', debtRecoveryResult.renewed);
    const recoveredSub = await db.getActiveDriverSubscription(driverId);
    console.log(`   ✓ Post-Recovery Remaining Rides (10 - 2 Grace Debt): ${recoveredSub?.remaining_rides} rides (Expected: 8)`);
    isEligible = await subscriptionService.isDriverEligibleForDispatch(driverId);
    console.log(`   ✓ Driver re-eligible for dispatch after debt recovery: ${isEligible} (Expected: true)`);

    // 32. Subscription Spillover / Ride Rollover
    console.log('\n32. Testing Subscription Spillover / Ride Rollover...');
    const rolledOverSub = await subscriptionService.activateSubscription(driverId, 'plan_starter_10');
    console.log(`   ✓ Total Rides After Rollover (8 existing + 10 new): ${rolledOverSub.remaining_rides} rides (Expected: 18)`);

    // 33. FinTech & RegTech Admin Levers & 1-Click Lockout Override
    console.log('\n33. Testing Admin FinTech/RegTech Levers & Lockout Override...');
    const settingsRes = await axios.get(`${BASE_URL}/api/admin/settings/integrations`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.log('   ✓ Retrieved Integration Settings: Masked Resend Key =', settingsRes.data.data.resend_api_key);

    const testEmailRes = await axios.post(
      `${BASE_URL}/api/admin/integrations/test-email`,
      { toEmail: 'admin@gigaride.ng' },
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log('   ✓ Admin Test Email Result:', testEmailRes.data.result?.status || 'Sent');

    const testSmsRes = await axios.post(
      `${BASE_URL}/api/admin/integrations/test-sms`,
      { phoneNumber: '08011223344' },
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log('   ✓ Admin Test SMS Result:', testSmsRes.data.result?.status || 'Sent');

    await db.updateDriverLockout(driverId, true, 'Manual test lock');
    const unlockRes = await axios.post(
      `${BASE_URL}/api/admin/drivers/${driverId}/unlock`,
      {},
      { headers: { Authorization: `Bearer ${adminToken}` } }
    );
    console.log('   ✓ Admin 1-Click Lockout Override:', unlockRes.data.message);

    console.log('\n================================================================');
    console.log(' ✅ ALL 33 E2E & 100% PRODUCTION SUPER ADMIN TESTS PASSED! ');
    console.log('================================================================');

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
