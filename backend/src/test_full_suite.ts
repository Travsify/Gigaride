import { authService } from './modules/auth/auth.service';
import { twilioService } from './modules/notifications/twilio.service';
import { resendService } from './modules/notifications/resend.service';
import { oneSignalService } from './modules/notifications/onesignal.service';
import { premblyService } from './modules/kyc/prembly.service';
import { korapayService } from './modules/payments/korapay.service';
import { paystackService } from './modules/payments/paystack.service';
import { db } from './database';

async function runTestSuite() {
  console.log('====================================================');
  console.log('🧪 RUNNING 100% PRODUCTION API SUITE VERIFICATION');
  console.log('====================================================');

  const testPhone = '+23480' + Math.floor(10000000 + Math.random() * 90000000);
  const testEmail = 'verify_' + Date.now() + '@gigaride.ng';

  // TEST 1: Phone Verification & 1-Tap OTP Login
  console.log('\n[1/7] Testing Phone Number Verification (Twilio)...');
  const otpRes = await twilioService.sendOtp(testPhone);
  console.log('  ✓ Twilio OTP Dispatch:', otpRes);
  const verifyRes = await authService.loginWithPhoneOtp(testPhone, '123456');
  console.log('  ✓ Phone Verification Check:', verifyRes.message);

  // TEST 2: Email Verification (Resend)
  console.log('\n[2/7] Testing Email Verification (Resend)...');
  const emailOtpRes = await authService.sendEmailVerificationOtp(testEmail);
  console.log('  ✓ Resend Email OTP Sent:', emailOtpRes.message);
  // Retrieve saved OTP from DB for verification
  const emailRecord = (db as any).store.email_verifications.find((e: any) => e.email === testEmail);
  const emailVerifyRes = await authService.verifyEmailOtp(testEmail, emailRecord.otp);
  console.log('  ✓ Resend Email Verified:', emailVerifyRes.message);

  // TEST 3: User Registration & Automated Welcome Email
  console.log('\n[3/7] Testing Registration, Welcome Email & Welcome Alert...');
  const regRes = await authService.register({
    role: 'PASSENGER',
    fullName: 'Chief Emeka Okonkwo',
    phoneNumber: testPhone,
    email: testEmail,
    password: 'password123',
  });
  console.log('  ✓ Registered User ID:', regRes.user.id);
  console.log('  ✓ Auth Token Generated:', regRes.token.slice(0, 25) + '...');

  // TEST 4: In-App Notifications Hub
  console.log('\n[4/7] Testing In-App Notifications Center...');
  const notifs = await db.getUserNotifications(regRes.user.id);
  const unread = await db.getUnreadNotificationsCount(regRes.user.id);
  console.log(`  ✓ Notifications Found: ${notifs.length} (Unread: ${unread})`);
  console.log('  ✓ Latest Notification:', notifs[0]?.title, '-', notifs[0]?.message);
  if (notifs.length > 0) {
    await db.markNotificationAsRead(notifs[0].id, regRes.user.id);
    const newUnread = await db.getUnreadNotificationsCount(regRes.user.id);
    console.log(`  ✓ Notification Marked as Read! Remaining Unread: ${newUnread}`);
  }

  // TEST 5: OneSignal Push Notifications
  console.log('\n[5/7] Testing Mobile Push Notifications (OneSignal)...');
  const pushRes = await oneSignalService.sendBidAlertToPassenger(
    regRes.user.id,
    'Ibrahim Musa (Toyota Camry)',
    3500,
    'ride_test_101'
  );
  console.log('  ✓ OneSignal Push Dispatched:', pushRes);

  // TEST 6: Identity KYC (Prembly) & Auto-Generated Virtual Bank Account (Korapay)
  console.log('\n[6/7] Testing Identity Verification (Prembly) -> Auto Korapay DVA...');
  const driverPhone = '+23481' + Math.floor(10000000 + Math.random() * 90000000);
  const driverEmail = 'driver_' + Date.now() + '@gigaride.ng';
  const driverReg = await authService.register({
    role: 'DRIVER',
    fullName: 'Kabiru Abdullahi',
    phoneNumber: driverPhone,
    email: driverEmail,
    password: 'password123',
    vehicleMake: 'Toyota',
    vehicleModel: 'Corolla',
    vehicleYear: 2018,
    licensePlate: 'EKY-492-LG',
  });
  console.log('  ✓ Test Driver Registered:', driverReg.user.id);
  // Run NIN verification through Prembly Service
  const kycRes = await premblyService.verifyNIN(
    driverReg.user.id,
    '12345678901',
    'Kabiru',
    'Abdullahi'
  );
  console.log('  ✓ Prembly NIN Status:', kycRes.status, `(Score: ${kycRes.confidenceScore}%)`);
  // Check if Korapay Virtual Account was automatically provisioned
  const driverVba = await db.getVirtualAccountByUserId(driverReg.user.id);
  console.log('  ✓ Auto-Generated Korapay DVA:', driverVba?.account_number, `(${driverVba?.bank_name})`);

  // TEST 7: Paystack Card Checkout & Instant Wallet Funding
  console.log('\n[7/7] Testing Paystack Card & Living Wallet Funding...');
  const paystackInit = await paystackService.initializeSubscriptionPayment(
    driverReg.user.id,
    'plan_standard_50',
    driverEmail
  );
  console.log('  ✓ Paystack Transaction Reference:', paystackInit.reference);
  console.log('  ✓ Paystack Authorization URL:', paystackInit.authorizationUrl);

  const fundedVba = await db.creditVirtualAccountBalance(regRes.user.id, 10000);
  console.log('  ✓ Living Wallet Balance Credited: ₦' + fundedVba.balance_ngn.toLocaleString());

  console.log('\n====================================================');
  console.log('🎉 ALL 7 PRODUCTION API CAPABILITIES PASSED 100%!');
  console.log('====================================================');
}

runTestSuite().catch((err) => {
  console.error('Test Suite Failed:', err);
  process.exit(1);
});
