import axios from 'axios';

const BASE_URL = 'http://localhost:4000';

interface TestResult {
  category: string;
  name: string;
  status: 'PASSED' | 'FAILED';
  httpStatus?: number;
  durationMs: number;
  details?: string;
}

const results: TestResult[] = [];

async function runTest(category: string, name: string, fn: () => Promise<{ httpStatus: number; details?: string }>) {
  const start = Date.now();
  try {
    const res = await fn();
    results.push({
      category,
      name,
      status: 'PASSED',
      httpStatus: res.httpStatus,
      durationMs: Date.now() - start,
      details: res.details,
    });
    console.log('  [PASSED] [' + category + '] ' + name + ' (HTTP ' + res.httpStatus + ', ' + (Date.now() - start) + 'ms) - ' + (res.details || 'OK'));
  } catch (err: any) {
    const httpStatus = err.response?.status || 500;
    const msg = err.response?.data?.message || err.message;
    results.push({
      category,
      name,
      status: 'FAILED',
      httpStatus,
      durationMs: Date.now() - start,
      details: typeof msg === 'object' ? JSON.stringify(msg) : msg,
    });
    console.error('  [FAILED] [' + category + '] ' + name + ' (HTTP ' + httpStatus + '): ' + (typeof msg === 'object' ? JSON.stringify(msg) : msg));
  }
}

async function main() {
  console.log('========================================================================');
  console.log('      GIGA RIDE PLATFORM - 100% PRODUCTION API VALIDATION SUITE        ');
  console.log('========================================================================\n');

  let passengerToken = '';
  let driverToken = '';
  let adminToken = '';
  let createdRideId = '';
  let testBeneficiaryId = '';

  const runSuffix = Date.now().toString().slice(-6);
  const testPhonePassenger = '+23480' + runSuffix;
  const testEmailPassenger = 'pass_' + runSuffix + '@getgigaride.com';
  const testPhoneDriver = '+23481' + runSuffix;
  const testEmailDriver = 'driver_' + runSuffix + '@getgigaride.com';
  const commonPass = 'ValidPass2026!';

  // ==========================================
  // 1. SYSTEM HEALTH & PLATFORM STATE
  // ==========================================
  await runTest('SYSTEM', 'GET /health', async () => {
    const res = await axios.get(BASE_URL + '/health');
    if (res.data.status !== 'online') throw new Error('Platform status not online');
    return { httpStatus: res.status, details: 'Platform: ' + res.data.platform + ', Currency: ' + res.data.currency + ', Model: ' + res.data.model };
  });

  // ==========================================
  // 2. AUTHENTICATION & VERIFICATION
  // ==========================================
  await runTest('AUTH', 'POST /api/auth/send-otp (Passenger Phone)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/send-otp', { phoneNumber: testPhonePassenger });
    return { httpStatus: res.status, details: res.data.message };
  });

  await runTest('AUTH', 'POST /api/auth/verify-otp (Passenger Phone Verify)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/verify-otp', { phoneNumber: testPhonePassenger, otpCode: '123456' });
    return { httpStatus: res.status, details: res.data.message };
  });

  await runTest('AUTH', 'POST /api/auth/send-email-otp (Passenger Email)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/send-email-otp', { email: testEmailPassenger });
    return { httpStatus: res.status, details: res.data.message };
  });

  await runTest('AUTH', 'POST /api/auth/verify-email (Passenger Email Verify)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/verify-email', { email: testEmailPassenger, otpCode: '123456' });
    return { httpStatus: res.status, details: res.data.message };
  });

  await runTest('AUTH', 'POST /api/auth/register (Passenger)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/register', {
      role: 'PASSENGER',
      fullName: 'Validation Passenger',
      phoneNumber: testPhonePassenger,
      email: testEmailPassenger,
      password: commonPass,
    });
    passengerToken = res.data.data.token;
    return { httpStatus: res.status, details: 'Passenger ID: ' + res.data.data.user.id + ', Name: ' + res.data.data.user.fullName };
  });

  await runTest('AUTH', 'POST /api/auth/register (Driver Onboarding)', async () => {
    await axios.post(BASE_URL + '/api/auth/verify-otp', { phoneNumber: testPhoneDriver, otpCode: '123456' });
    await axios.post(BASE_URL + '/api/auth/verify-email', { email: testEmailDriver, otpCode: '123456' });
    const res = await axios.post(BASE_URL + '/api/auth/register', {
      role: 'DRIVER',
      fullName: 'Validation Driver Pro',
      phoneNumber: testPhoneDriver,
      email: testEmailDriver,
      password: commonPass,
      vehicleMake: 'Toyota',
      vehicleModel: 'Corolla 1.8L',
      vehicleYear: 2020,
      licensePlate: 'APP-' + runSuffix.slice(0, 3) + '-XY',
      vehicleColor: 'Black Metallic',
      nin: '11223344556',
    });
    driverToken = res.data.data.token;
    return { httpStatus: res.status, details: 'Driver ID: ' + res.data.data.user.id + ', Plate: APP-' + runSuffix.slice(0, 3) + '-XY' };
  });

  await runTest('AUTH', 'POST /api/auth/login (Login via Phone)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/login', {
      identifier: testPhonePassenger,
      password: commonPass,
    });
    return { httpStatus: res.status, details: 'Authenticated: ' + res.data.data.user.fullName };
  });

  await runTest('AUTH', 'POST /api/auth/login (Login via Email)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/login', {
      identifier: testEmailPassenger,
      password: commonPass,
    });
    return { httpStatus: res.status, details: 'Authenticated: ' + res.data.data.user.fullName };
  });

  await runTest('AUTH', 'POST /api/auth/login-otp (1-Tap Passwordless)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/login-otp', {
      phoneNumber: testPhonePassenger,
      otpCode: '123456',
    });
    return { httpStatus: res.status, details: res.data.message };
  });

  await runTest('AUTH', 'GET /api/auth/me (Bearer Token Validation)', async () => {
    const res = await axios.get(BASE_URL + '/api/auth/me', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Verified user: ' + res.data.data.email + ', Role: ' + res.data.data.role };
  });

  await runTest('AUTH', 'POST /api/auth/forgot-password & reset-password', async () => {
    await axios.post(BASE_URL + '/api/auth/forgot-password', { identifier: testPhonePassenger });
    const resetRes = await axios.post(BASE_URL + '/api/auth/reset-password', {
      phoneNumber: testPhonePassenger,
      otpCode: '123456',
      newPassword: commonPass,
    });
    return { httpStatus: resetRes.status, details: resetRes.data.message };
  });

  // ==========================================
  // 3. RIDES & BIDDING ENGINE
  // ==========================================
  await runTest('RIDES', 'POST /api/rides/estimate (Lagos Pricing & Levy Calculation)', async () => {
    const res = await axios.post(BASE_URL + '/api/rides/estimate', {
      pickupLat: 6.5244,
      pickupLng: 3.3792,
      dropoffLat: 6.4281,
      dropoffLng: 3.4219,
    });
    return { httpStatus: res.status, details: 'Distance: ' + res.data.data.distanceKm + 'km, Estimate: NGN ' + res.data.data.suggestedFareNgn };
  });

  await runTest('RIDES', 'POST /api/rides/request (Broadcast to Radar)', async () => {
    const res = await axios.post(BASE_URL + '/api/rides/request', {
      pickupAddress: 'Victoria Island, Lagos',
      dropoffAddress: 'Ikeja City Mall, Lagos',
      pickupLat: 6.4281,
      pickupLng: 3.4219,
      dropoffLat: 6.5933,
      dropoffLng: 3.3557,
      riderOfferNgn: 4500,
    }, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    createdRideId = res.data.data.id;
    return { httpStatus: res.status, details: 'Ride ID: ' + createdRideId + ', Offer: NGN ' + res.data.data.rider_offer_ngn };
  });

  await runTest('RIDES', 'POST /api/rides/schedule (Advance Airport / Interstate)', async () => {
    const scheduledDate = new Date(Date.now() + 86400000).toISOString();
    const res = await axios.post(BASE_URL + '/api/rides/schedule', {
      pickupAddress: 'Murtala Muhammed International Airport, Ikeja',
      dropoffAddress: 'Eko Hotels & Suites, Victoria Island',
      pickupLat: 6.5774,
      pickupLng: 3.3211,
      dropoffLat: 6.4281,
      dropoffLng: 3.4219,
      scheduledFor: scheduledDate,
      riderOfferNgn: 12000,
      flightNumber: 'BA075',
      isAirport: true,
      isInterstate: false,
    }, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Scheduled Ride ID: ' + res.data.data.id + ', Flight: BA075, Fare: NGN 12,000' };
  });

  await runTest('RIDES', 'GET /api/rides/:id (Ride Inspection)', async () => {
    const res = await axios.get(BASE_URL + '/api/rides/' + createdRideId, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Ride: ' + res.data.data.pickup_address + ' -> ' + res.data.data.dropoff_address };
  });

  await runTest('RIDES', 'GET /api/rides/history/passenger (Trip Archive)', async () => {
    const res = await axios.get(BASE_URL + '/api/rides/history/passenger', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Recorded Trips: ' + res.data.data.length };
  });

  // ==========================================
  // 4. LIVING WALLET, CARDS & BENEFICIARIES
  // ==========================================
  await runTest('PAYMENTS', 'GET /api/payments/wallet (Main Balance & SafeLock Vault)', async () => {
    const res = await axios.get(BASE_URL + '/api/payments/wallet', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    const acc = res.data.data.virtualAccount;
    return { httpStatus: res.status, details: 'NUBAN: ' + acc?.account_number + ', Bank: ' + acc?.bank_name + ', Balance: NGN ' + acc?.balance_ngn };
  });

  await runTest('PAYMENTS', 'GET /api/payments/virtual-account (Dedicated NUBAN)', async () => {
    const res = await axios.get(BASE_URL + '/api/payments/virtual-account', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Assigned Account: ' + res.data.data.account_number + ' (' + res.data.data.bank_name + ')' };
  });

  await runTest('PAYMENTS', 'POST /api/payments/korapay/simulate-bank-transfer (Inflow)', async () => {
    const res = await axios.post(BASE_URL + '/api/payments/korapay/simulate-bank-transfer', {
      amountNgn: 25000,
    }, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Funded NGN 25,000. New Balance: NGN ' + res.data.data.balance_ngn };
  });

  let dynamicTransferRef = '';
  await runTest('PAYMENTS', 'POST /api/payments/wallet/dynamic-transfer (Dynamic Paystack Account)', async () => {
    const res = await axios.post(BASE_URL + '/api/payments/wallet/dynamic-transfer', {
      amountNgn: 15000,
    }, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    dynamicTransferRef = res.data.data.reference;
    return { httpStatus: res.status, details: 'Generated: ' + res.data.data.bankName + ' NUBAN ' + res.data.data.accountNumber + ' for NGN ' + res.data.data.amountNgn };
  });

  await runTest('PAYMENTS', 'POST /api/payments/wallet/verify-transfer (Verify & Credit)', async () => {
    const res = await axios.post(BASE_URL + '/api/payments/wallet/verify-transfer', {
      reference: dynamicTransferRef,
    }, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Credited: NGN ' + res.data.data.amountNgn + ', New Balance: NGN ' + res.data.data.newBalanceNgn };
  });

  await runTest('PAYMENTS', 'POST /api/payments/wallet/swap (Main to Vault)', async () => {
    const res = await axios.post(BASE_URL + '/api/payments/wallet/swap', {
      direction: 'MAIN_TO_VAULT',
      amountNgn: 10000,
    }, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Vault Balance: NGN ' + res.data.data.vault_balance_ngn + ', Main: NGN ' + res.data.data.balance_ngn };
  });

  await runTest('PAYMENTS', 'POST /api/payments/wallet/beneficiaries (Save Recipient)', async () => {
    const res = await axios.post(BASE_URL + '/api/payments/wallet/beneficiaries', {
      account_name: 'Babajide Sanwo-Olu',
      account_number: '0123456789',
      bank_name: 'Guaranty Trust Bank',
      bank_code: '058',
      nickname: 'Governor Payout',
      is_pinned: true,
    }, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    testBeneficiaryId = res.data.data.id;
    return { httpStatus: res.status, details: 'Saved: ' + res.data.data.account_name + ' - ' + res.data.data.account_number + ' (' + res.data.data.bank_name + ')' };
  });

  await runTest('PAYMENTS', 'GET /api/payments/wallet/beneficiaries (Living Memory Search)', async () => {
    const res = await axios.get(BASE_URL + '/api/payments/wallet/beneficiaries?search=Babajide&days=90', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    if (res.data.data.length === 0) throw new Error('Beneficiary search failed');
    return { httpStatus: res.status, details: 'Matches found: ' + res.data.data.length + ' (' + res.data.data[0].account_name + ')' };
  });

  await runTest('PAYMENTS', 'GET /api/payments/wallet/statement (Transaction Feed)', async () => {
    const res = await axios.get(BASE_URL + '/api/payments/wallet/statement', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Statement Entries: ' + res.data.data.length };
  });

  await runTest('PAYMENTS', 'GET /api/payments/cards (Tokenized Card Vault)', async () => {
    const res = await axios.get(BASE_URL + '/api/payments/cards', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Active Saved Cards: ' + res.data.data.length };
  });

  await runTest('PAYMENTS', 'GET /api/payments/cards/transactions (Card Audit)', async () => {
    const res = await axios.get(BASE_URL + '/api/payments/cards/transactions', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Card Transactions Tracked: ' + res.data.data.length };
  });

  // ==========================================
  // 5. SUBSCRIPTIONS & ZERO COMMISSION DRIVER PACKS
  // ==========================================
  await runTest('SUBSCRIPTION', 'GET /api/subscriptions/plans (Zero Commission)', async () => {
    const res = await axios.get(BASE_URL + '/api/subscriptions/plans');
    return { httpStatus: res.status, details: 'Active Tier Plans: ' + res.data.data.length };
  });

  await runTest('SUBSCRIPTION', 'GET /api/subscriptions/status (Driver Status)', async () => {
    const res = await axios.get(BASE_URL + '/api/subscriptions/status', {
      headers: { Authorization: 'Bearer ' + driverToken },
    });
    return { httpStatus: res.status, details: 'Remaining Rides: ' + res.data.data.remainingRides + ', Active: ' + res.data.data.hasActiveSubscription };
  });

  await runTest('SUBSCRIPTION', 'POST /api/subscriptions/freeze (Breakdown Shield)', async () => {
    const res = await axios.post(BASE_URL + '/api/subscriptions/freeze', {
      reason: 'Vehicle routine maintenance',
    }, {
      headers: { Authorization: 'Bearer ' + driverToken },
    });
    return { httpStatus: res.status, details: 'Freeze Status: ' + res.data.data.is_frozen };
  });

  await runTest('SUBSCRIPTION', 'POST /api/subscriptions/unfreeze (Resume Shield)', async () => {
    const res = await axios.post(BASE_URL + '/api/subscriptions/unfreeze', {}, {
      headers: { Authorization: 'Bearer ' + driverToken },
    });
    return { httpStatus: res.status, details: 'Resumed. Active: ' + (!res.data.data.is_frozen) };
  });

  await runTest('SUBSCRIPTION', 'PUT /api/subscriptions/auto-topup-settings (Auto Renewal)', async () => {
    const res = await axios.put(BASE_URL + '/api/subscriptions/auto-topup-settings', {
      autoTopupEnabled: true,
      preferredPlanId: 'plan_unlimited_weekly',
    }, {
      headers: { Authorization: 'Bearer ' + driverToken },
    });
    return { httpStatus: res.status, details: res.data.message };
  });

  // ==========================================
  // 6. KYC & IDENTITY VERIFICATION (WHITE-LABEL)
  // ==========================================
  await runTest('KYC', 'POST /api/kyc/verify-nin (NIMC Integration)', async () => {
    const res = await axios.post(BASE_URL + '/api/kyc/verify-nin', {
      nin: '11223344556',
      firstName: 'Validation',
      lastName: 'Driver',
    }, {
      headers: { Authorization: 'Bearer ' + driverToken },
    });
    return { httpStatus: res.status, details: 'Verification: ' + res.data.data.status };
  });

  await runTest('KYC', 'POST /api/kyc/verify-license (FRSC Registry)', async () => {
    const res = await axios.post(BASE_URL + '/api/kyc/verify-license', {
      licenseNumber: 'AAA12345AA00',
      firstName: 'Validation',
      lastName: 'Driver',
    }, {
      headers: { Authorization: 'Bearer ' + driverToken },
    });
    return { httpStatus: res.status, details: 'FRSC Status: ' + res.data.data.status };
  });

  // ==========================================
  // 7. NOTIFICATIONS & ALERTS
  // ==========================================
  await runTest('NOTIFICATIONS', 'GET /api/notifications (In-App Feed)', async () => {
    const res = await axios.get(BASE_URL + '/api/notifications', {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Notifications: ' + res.data.data.notifications.length + ', Unread: ' + res.data.data.unreadCount };
  });

  await runTest('NOTIFICATIONS', 'PATCH /api/notifications/read-all (Read Status)', async () => {
    const res = await axios.patch(BASE_URL + '/api/notifications/read-all', {}, {
      headers: { Authorization: 'Bearer ' + passengerToken },
    });
    return { httpStatus: res.status, details: 'Marked read: ' + res.data.count };
  });

  // ==========================================
  // 8. SUPER ADMIN OPERATIONS CONSOLE (engine.getgigaride.com)
  // ==========================================
  await runTest('ADMIN', 'POST /api/auth/login (Admin Master Key)', async () => {
    const res = await axios.post(BASE_URL + '/api/auth/login', {
      identifier: 'admin@gigaride.ng',
      password: 'admin_password_2026',
    });
    adminToken = res.data.data.token;
    return { httpStatus: res.status, details: 'Admin: ' + res.data.data.user.fullName + ', Role: ' + res.data.data.user.role };
  });

  await runTest('ADMIN', 'GET /api/admin/analytics (Operations KPI & MOT)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/analytics', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Total Rides: ' + res.data.data.totalTrips + ', Drivers: ' + res.data.data.totalDrivers + ', Rev: NGN ' + (res.data.data.totalRevenueKobo / 100).toLocaleString() };
  });

  await runTest('ADMIN', 'GET /api/admin/drivers (Fleet Registry)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/drivers', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Registered Drivers: ' + res.data.data.length };
  });

  await runTest('ADMIN', 'GET /api/admin/drivers/quality-watchlist (Strike Watch)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/drivers/quality-watchlist', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Drivers on Watchlist: ' + res.data.data.length };
  });

  await runTest('ADMIN', 'GET /api/admin/passengers (Rider Registry)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/passengers', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Registered Passengers: ' + res.data.data.length };
  });

  await runTest('ADMIN', 'GET /api/admin/transactions (System Ledger)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/transactions', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Transactions: ' + res.data.data.length };
  });

  await runTest('ADMIN', 'GET /api/admin/settings (Market Engine Dynamics)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/settings', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Petrol: NGN ' + res.data.data.petrol_price_ngn + '/L, Base: NGN ' + res.data.data.base_flag_fall_ngn + ', MOT Levy: NGN ' + res.data.data.lagos_mot_levy_ngn };
  });

  await runTest('ADMIN', 'GET /api/admin/sos (Emergency Incident Center)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/sos', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Active SOS incidents: ' + res.data.data.length };
  });

  await runTest('ADMIN', 'GET /api/admin/fleet/live (Real-Time GPS Telemetry)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/fleet/live', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Live active GPS units: ' + res.data.data.length };
  });

  await runTest('ADMIN', 'GET /api/admin/finance/lasg-mot-export (LASG MOT Levy Audit CSV)', async () => {
    const res = await axios.get(BASE_URL + '/api/admin/finance/lasg-mot-export', {
      headers: { Authorization: 'Bearer ' + adminToken },
    });
    return { httpStatus: res.status, details: 'Generated official CSV audit with headers & line items (' + res.data.length + ' bytes)' };
  });

  console.log('\n========================================================================');
  const passed = results.filter((r) => r.status === 'PASSED').length;
  const failed = results.filter((r) => r.status === 'FAILED').length;
  console.log('  VALIDATION SUMMARY: ' + passed + '/' + results.length + ' PASSED (Failed: ' + failed + ')');
  console.log('========================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
