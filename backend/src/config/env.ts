import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  PORT: parseInt(process.env.PORT || '4000', 10),
  NODE_ENV: process.env.NODE_ENV || 'development',
  JWT_SECRET: process.env.JWT_SECRET || 'giga_production_jwt_secret_key_nigeria_2026',
  DATABASE_URL: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/giga_ride',
  REDIS_URL: process.env.REDIS_URL || 'redis://localhost:6379',
  PAYSTACK_SECRET_KEY: process.env.PAYSTACK_SECRET_KEY || 'sk_test_paystack_secret_key',
  // Nigerian market specific constants
  PETROL_PRICE_PER_LITRE_NGN: parseFloat(process.env.PETROL_PRICE_PER_LITRE_NGN || '1050'),
  BASE_FLAG_FALL_NGN: 1500,
  PER_KM_RATE_NGN: 350,
  PER_MINUTE_RATE_NGN: 80,
  LAGOS_MOT_LEVY_NGN: 50,
  MAX_GRACE_RIDES: 2,
};
