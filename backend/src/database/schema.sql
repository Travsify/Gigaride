-- Production PostgreSQL + PostGIS Schema for Giga Ride Platform

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role VARCHAR(20) NOT NULL CHECK (role IN ('PASSENGER', 'DRIVER', 'ADMIN')),
    admin_role VARCHAR(30) DEFAULT 'SUPER_ADMIN' CHECK (admin_role IN ('SUPER_ADMIN', 'SUPPORT_AGENT', 'KYC_OFFICER', 'FINANCE_ADMIN')),
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- 2. Driver Profiles
CREATE TABLE IF NOT EXISTS driver_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_make VARCHAR(50) NOT NULL,
    vehicle_model VARCHAR(50) NOT NULL,
    vehicle_year INT NOT NULL,
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    vehicle_color VARCHAR(30) NOT NULL,
    kyc_status VARCHAR(20) DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    rejection_reason TEXT,
    account_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (account_status IN ('ACTIVE', 'SUSPENDED', 'BANNED')),
    nin VARCHAR(20),
    bvn VARCHAR(20),
    driver_license_expiry TIMESTAMP WITH TIME ZONE,
    insurance_expiry TIMESTAMP WITH TIME ZONE,
    road_worthiness_expiry TIMESTAMP WITH TIME ZONE,
    lasdri_card_number VARCHAR(50),
    lasdri_expiry TIMESTAMP WITH TIME ZONE,
    rating_average NUMERIC(3, 2) DEFAULT 5.0,
    total_trips_completed INT DEFAULT 0,
    is_online BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_driver_profile UNIQUE (driver_id)
);

CREATE INDEX IF NOT EXISTS idx_driver_kyc ON driver_profiles(kyc_status);
CREATE INDEX IF NOT EXISTS idx_driver_online ON driver_profiles(is_online);
CREATE INDEX IF NOT EXISTS idx_driver_status ON driver_profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_driver_license_exp ON driver_profiles(driver_license_expiry);

-- 3. Subscription Plans
CREATE TABLE IF NOT EXISTS subscription_plans (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    plan_type VARCHAR(20) NOT NULL CHECK (plan_type IN ('RIDE_COUNT', 'UNLIMITED')),
    total_rides INT, -- NULL for UNLIMITED
    duration_days INT NOT NULL,
    price_kobo BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 4. Driver Subscriptions
CREATE TABLE IF NOT EXISTS driver_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id VARCHAR(50) NOT NULL REFERENCES subscription_plans(id),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'EXHAUSTED', 'EXPIRED')),
    remaining_rides INT NOT NULL DEFAULT 0,
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_driver_sub_status ON driver_subscriptions(driver_id, status);

-- 5. Subscription Credit Audits (Manual Support/Admin allocations)
CREATE TABLE IF NOT EXISTS subscription_credit_audits (
    id VARCHAR(50) PRIMARY KEY,
    admin_id UUID NOT NULL REFERENCES users(id),
    driver_id UUID NOT NULL REFERENCES users(id),
    rides_added INT NOT NULL,
    previous_rides INT NOT NULL,
    new_rides INT NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_credit_audit_driver ON subscription_credit_audits(driver_id);

-- 6. Rides
CREATE TABLE IF NOT EXISTS rides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES users(id),
    driver_id UUID REFERENCES users(id),
    pickup_lat DOUBLE PRECISION NOT NULL,
    pickup_lng DOUBLE PRECISION NOT NULL,
    pickup_address TEXT NOT NULL,
    dropoff_lat DOUBLE PRECISION NOT NULL,
    dropoff_lng DOUBLE PRECISION NOT NULL,
    dropoff_address TEXT NOT NULL,
    suggested_fare_ngn INT NOT NULL,
    rider_offer_ngn INT NOT NULL,
    agreed_fare_ngn INT,
    distance_km DOUBLE PRECISION NOT NULL,
    status VARCHAR(30) DEFAULT 'REQUESTED' CHECK (status IN (
        'REQUESTED', 'NEGOTIATING', 'ACCEPTED', 'ARRIVED', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_rides_rider ON rides(rider_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);

-- 7. Ride Bids (Bargaining table)
CREATE TABLE IF NOT EXISTS ride_bids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES users(id),
    counter_fare_ngn INT NOT NULL,
    eta_minutes INT NOT NULL,
    status VARCHAR(20) DEFAULT 'OFFERED' CHECK (status IN ('OFFERED', 'ACCEPTED', 'REJECTED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bids_ride ON ride_bids(ride_id);

-- 8. Emergency SOS Incidents
CREATE TABLE IF NOT EXISTS sos_incidents (
    id VARCHAR(50) PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    driver_id UUID REFERENCES users(id),
    rider_id UUID NOT NULL REFERENCES users(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_REVIEW', 'RESOLVED')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_sos_status ON sos_incidents(status);

-- 9. Payment Transactions
CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reference VARCHAR(100) UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id),
    amount_kobo BIGINT NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED')),
    payment_type VARCHAR(50) DEFAULT 'SUBSCRIPTION_PURCHASE',
    channel VARCHAR(50),
    meta_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tx_reference ON payment_transactions(reference);
CREATE INDEX IF NOT EXISTS idx_tx_user ON payment_transactions(user_id);

-- 10. Dynamic Platform Settings (Fuel Levers)
CREATE TABLE IF NOT EXISTS platform_settings (
    id INT PRIMARY KEY DEFAULT 1,
    petrol_price_ngn NUMERIC(10, 2) NOT NULL DEFAULT 1050,
    base_flag_fall_ngn NUMERIC(10, 2) NOT NULL DEFAULT 1500,
    per_km_rate_ngn NUMERIC(10, 2) NOT NULL DEFAULT 350,
    per_minute_rate_ngn NUMERIC(10, 2) NOT NULL DEFAULT 80,
    lagos_mot_levy_ngn NUMERIC(10, 2) NOT NULL DEFAULT 50,
    welcome_bonus_rides INT NOT NULL DEFAULT 5,
    search_radius_km NUMERIC(5, 2) NOT NULL DEFAULT 7.0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 11. Immutable Admin Operations Audit Log
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id VARCHAR(50) PRIMARY KEY,
    admin_id UUID NOT NULL REFERENCES users(id),
    admin_email VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id VARCHAR(100),
    details JSONB NOT NULL,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_admin ON admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON admin_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_created ON admin_audit_logs(created_at);

-- 12. In-App Passenger & Driver Disputes Desk
CREATE TABLE IF NOT EXISTS disputes (
    id VARCHAR(50) PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    reporter_id UUID NOT NULL REFERENCES users(id),
    reporter_role VARCHAR(20) NOT NULL CHECK (reporter_role IN ('PASSENGER', 'DRIVER')),
    dispute_type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'DISMISSED')),
    resolution_notes TEXT,
    driver_strike_applied BOOLEAN DEFAULT false,
    compensation_rides INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_ride ON disputes(ride_id);

-- 13. High-Resolution Trip GPS Breadcrumbs (Route Playback & Anti-Kidnap)
CREATE TABLE IF NOT EXISTS ride_gps_breadcrumbs (
    id VARCHAR(50) PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES users(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed_kmh DOUBLE PRECISION DEFAULT 0,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_breadcrumbs_ride ON ride_gps_breadcrumbs(ride_id);

