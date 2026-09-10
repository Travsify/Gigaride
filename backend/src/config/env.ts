import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  PORT: parseInt(process.env.PORT || '4000', 10),
  NODE_ENV: process.env.NODE_ENV || 'production',
  API_BASE_URL: process.env.API_BASE_URL || 'https://engine.getgigaride.com',
  JWT_SECRET: process.env.JWT_SECRET || 'giga_production_jwt_secret_key_nigeria_2026',
  DATABASE_URL: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/giga_ride',
  REDIS_URL: process.env.REDIS_URL || 'redis://localhost:6379',

  // Fincra Payment Gateway, Virtual Accounts & Instant Payouts
  FINCRA_BASE_URL: process.env.FINCRA_BASE_URL || 'https://api.fincra.com',
  FINCRA_SECRET_KEY: process.env.FINCRA_SECRET_KEY || '',
  FINCRA_PUBLIC_KEY: process.env.FINCRA_PUBLIC_KEY || '',
  FINCRA_BUSINESS_ID: process.env.FINCRA_BUSINESS_ID || '',
  FINCRA_WEBHOOK_SECRET: process.env.FINCRA_WEBHOOK_SECRET || '',
  FINCRA_FEE_PERCENT: parseFloat(process.env.FINCRA_FEE_PERCENT || '1.5'),
  FINCRA_FEE_CAP: parseFloat(process.env.FINCRA_FEE_CAP || '2000'),
  FINCRA_WITHDRAWAL_FEE_NGN: parseFloat(process.env.FINCRA_WITHDRAWAL_FEE_NGN || '50'),
  ADMIN_WITHDRAWAL_FEE_PERCENT: parseFloat(process.env.ADMIN_WITHDRAWAL_FEE_PERCENT || '0.5'),

  // Maplerad Crypto & FX Rail (USDT Funding -> Naira Wallet Conversion)
  MAPLERAD_BASE_URL: process.env.MAPLERAD_BASE_URL || 'https://api.maplerad.com/v1',
  MAPLERAD_SECRET_KEY: process.env.MAPLERAD_SECRET_KEY || '',
  MAPLERAD_PUBLIC_KEY: process.env.MAPLERAD_PUBLIC_KEY || '',
  MAPLERAD_WEBHOOK_SECRET: process.env.MAPLERAD_WEBHOOK_SECRET || '',
  MAPLERAD_USDT_NGN_FALLBACK_RATE: parseFloat(process.env.MAPLERAD_USDT_NGN_FALLBACK_RATE || '1550'),

  // OneSignal Push Notifications
  ONESIGNAL_APP_ID: process.env.ONESIGNAL_APP_ID || '',
  ONESIGNAL_REST_API_KEY: process.env.ONESIGNAL_REST_API_KEY || '',

  // Prembly Identity & KYC
  PREMBLY_BASE_URL: process.env.PREMBLY_BASE_URL || 'https://api.prembly.com/identitypass/verification',
  PREMBLY_API_KEY: process.env.PREMBLY_API_KEY || '',
  PREMBLY_APP_ID: process.env.PREMBLY_APP_ID || '',
  PREMBLY_PUBLIC_KEY: process.env.PREMBLY_PUBLIC_KEY || '',

  // Legacy fallback placeholders for transition
  PAYSTACK_BASE_URL: process.env.PAYSTACK_BASE_URL || 'https://api.paystack.co',
  PAYSTACK_SECRET_KEY: process.env.PAYSTACK_SECRET_KEY || '',
  PAYSTACK_PUBLIC_KEY: process.env.PAYSTACK_PUBLIC_KEY || '',
  PAYSTACK_WEBHOOK_SECRET: process.env.PAYSTACK_WEBHOOK_SECRET || '',
  KORAPAY_SECRET_KEY: process.env.KORAPAY_SECRET_KEY || '',
  KORAPAY_PUBLIC_KEY: process.env.KORAPAY_PUBLIC_KEY || '',
  KORAPAY_ENCRYPTION_KEY: process.env.KORAPAY_ENCRYPTION_KEY || '',

  // Resend Transactional Emails
  RESEND_API_KEY: process.env.RESEND_API_KEY || '',
  RESEND_FROM_EMAIL: process.env.RESEND_FROM_EMAIL || 'info@getgigaride.com',

  // Twilio SMS & OTP Verification
  TWILIO_ACCOUNT_SID: process.env.TWILIO_ACCOUNT_SID || '',
  TWILIO_AUTH_TOKEN: process.env.TWILIO_AUTH_TOKEN || '',
  TWILIO_PHONE_NUMBER: process.env.TWILIO_PHONE_NUMBER || '+15005550006',

  // Nigerian market specific constants
  PETROL_PRICE_PER_LITRE_NGN: parseFloat(process.env.PETROL_PRICE_PER_LITRE_NGN || '1050'),
  BASE_FLAG_FALL_NGN: 1500,
  PER_KM_RATE_NGN: 350,
  PER_MINUTE_RATE_NGN: 80,
  LAGOS_MOT_LEVY_NGN: 50,
  MAX_GRACE_RIDES: 2,
};
