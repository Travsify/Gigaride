import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { db, UserRow } from '../../database';
import { ENV } from '../../config/env';
import { AuthResponse, JwtPayload, LoginDto, RegisterUserDto } from './auth.types';
import { resendService } from '../notifications/resend.service';
import { twilioService } from '../notifications/twilio.service';
import { oneSignalService } from '../notifications/onesignal.service';

export class AuthService {
  public async register(dto: RegisterUserDto): Promise<AuthResponse> {
    // 0. Mandatory Phone Verification Check
    const phoneVerified = await db.isPhoneVerified(dto.phoneNumber);
    if (!phoneVerified) {
      throw new Error('Phone number must be verified via SMS OTP before registration. Please verify your phone number first.');
    }

    // 1. Check if user already exists
    const existingPhone = await db.findUserByPhone(dto.phoneNumber);
    if (existingPhone) {
      throw new Error('A user with this phone number is already registered.');
    }

    const existingEmail = await db.findUserByEmail(dto.email);
    if (existingEmail) {
      throw new Error('A user with this email address is already registered.');
    }

    // 2. Hash password
    const passwordHash = await bcrypt.hash(dto.password, 10);

    // 3. Create user
    const userId = uuidv4();
    const newUser: UserRow = {
      id: userId,
      role: dto.role,
      full_name: dto.fullName,
      phone_number: dto.phoneNumber,
      email: dto.email,
      password_hash: passwordHash,
      is_phone_verified: true,
      created_at: new Date().toISOString(),
    };
    await db.createUser(newUser);

    // 4. If driver, create driver profile & give 5 Free Welcome Rides!
    let driverProfile = undefined;
    if (dto.role === 'DRIVER') {
      if (!dto.vehicleMake || !dto.vehicleModel || !dto.licensePlate) {
        throw new Error('Vehicle make, model, and license plate are required for driver registration.');
      }

      driverProfile = await db.createDriverProfile({
        id: uuidv4(),
        driver_id: userId,
        vehicle_make: dto.vehicleMake,
        vehicle_model: dto.vehicleModel,
        vehicle_year: dto.vehicleYear || 2015,
        license_plate: dto.licensePlate.toUpperCase(),
        vehicle_color: dto.vehicleColor || 'Silver',
        kyc_status: 'PENDING',
        rejection_reason: null,
        account_status: 'ACTIVE',
        rating_average: 5.0,
        total_trips_completed: 0,
        nin: dto.nin,
        bvn: dto.bvn,
        is_online: false,
        created_at: new Date().toISOString(),
      });

      // Automatically seed 5 promotional welcome rides so driver can test immediately!
      await db.createDriverSubscription({
        id: uuidv4(),
        driver_id: userId,
        plan_id: 'plan_starter_10',
        status: 'ACTIVE',
        remaining_rides: 5,
        starts_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days promo
        created_at: new Date().toISOString(),
      });
    }

    // 5. Dispatch Welcome Email & In-App Notification
    try {
      await resendService.sendEmail({
        to: newUser.email,
        subject: 'Welcome to Giga Ride Nigeria — Zero Commission Mobility',
        html: `
          <div style="font-family: Arial, sans-serif; background: #0A0F1D; color: #F8FAFC; padding: 28px; border-radius: 16px; max-width: 540px; margin: 0 auto;">
            <div style="text-align: center; margin-bottom: 24px;">
              <h1 style="color: #14B8A6; margin: 0; font-size: 24px;">🚖 Giga Ride Nigeria</h1>
              <p style="color: #94A3B8; font-size: 13px; margin-top: 4px;">Decacorn Zero-Commission Mobility</p>
            </div>
            <p style="font-size: 15px;">Hello <strong>${newUser.full_name}</strong>,</p>
            <p style="color: #CBD5E1; font-size: 14px; line-height: 1.5;">
              Welcome aboard Nigeria's fairest mobility ecosystem. Whether you're commuting across Lagos, Abuja, or Port Harcourt, you get 100% fair pricing, live auction bidding, and our NDPR asymmetric privacy shield.
            </p>
            <div style="background: #131C31; border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 16px; margin: 20px 0;">
              <p style="margin: 0 0 8px 0; color: #10B981; font-weight: bold; font-size: 13px;">✓ Zero Driver Exploitation (0% Trip Commission)</p>
              <p style="margin: 0 0 8px 0; color: #10B981; font-weight: bold; font-size: 13px;">✓ Dedicated Virtual Bank Accounts (Providus / Wema)</p>
              <p style="margin: 0; color: #10B981; font-weight: bold; font-size: 13px;">✓ 256-Bit TLS & NDPR Regulated Privacy Shield</p>
            </div>
            <p style="color: #64748B; font-size: 12px; text-align: center; margin-top: 24px;">
              © 2026 Giga Ride Nigeria Ltd. Lagos, Nigeria.
            </p>
          </div>
        `,
      });

      // 5a. In-App Notification Center
      await db.createNotification({
        user_id: userId,
        title: 'Welcome to Giga Ride! 🎉',
        message: 'Your account is active. Experience fair pricing with 0% platform commission on every trip.',
        type: 'SYSTEM',
        meta_data: { role: dto.role },
      });

      // 5b. Mobile Push Notification via OneSignal
      try {
        await oneSignalService.sendPush({
          userIds: [userId],
          heading: 'Welcome to Giga Ride! 🎉',
          content: 'Your account is active. Experience fair pricing with 0% platform commission on every trip.',
          data: { type: 'WELCOME', role: dto.role },
        });
      } catch (pushErr: any) {
        console.warn('[Welcome Push Notification Warning]', pushErr.message);
      }
    } catch (e: any) {
      console.warn('[Welcome Notification Warning]', e.message);
    }

    // 6. Generate token
    const token = this.generateToken(newUser);

    return {
      token,
      user: {
        id: newUser.id,
        role: newUser.role,
        fullName: newUser.full_name,
        phoneNumber: newUser.phone_number,
        email: newUser.email,
      },
      driverProfile,
    };
  }

  public async login(dto: LoginDto): Promise<AuthResponse> {
    // 1. Find user by phone or email
    let user = await db.findUserByPhone(dto.identifier);
    if (!user) {
      user = await db.findUserByEmail(dto.identifier);
    }
    if (!user && dto.identifier.toLowerCase().includes('@giga.internal')) {
      const alias = dto.identifier.toLowerCase().replace('@giga.internal', '@gigaride.ng');
      user = await db.findUserByEmail(alias);
    }
    if (!user && dto.identifier.toLowerCase().includes('@gigaride.ng')) {
      const alias = dto.identifier.toLowerCase().replace('@gigaride.ng', '@giga.internal');
      user = await db.findUserByEmail(alias);
    }

    if (!user) {
      throw new Error('Invalid phone/email or password.');
    }

    // 2. Verify password
    const isMatch = await bcrypt.compare(dto.password, user.password_hash);
    if (!isMatch) {
      throw new Error('Invalid phone/email or password.');
    }

    // 2b. Check Phone Verification
    if (!user.is_phone_verified) {
      // Auto-dispatch OTP so user can verify immediately
      try {
        await twilioService.sendOtp(user.phone_number);
      } catch (_) {}
      const err: any = new Error('Phone number not verified. A 6-digit verification code has been sent to your phone via SMS.');
      err.requiresPhoneVerification = true;
      err.phoneNumber = user.phone_number;
      throw err;
    }

    // 3. Load driver profile if driver
    let driverProfile = undefined;
    if (user.role === 'DRIVER') {
      driverProfile = await db.getDriverProfile(user.id);
    }

    // 4. Generate token
    const token = this.generateToken(user);

    return {
      token,
      user: {
        id: user.id,
        role: user.role,
        adminRole: user.role === 'ADMIN' ? (user.admin_role || 'SUPER_ADMIN') : undefined,
        admin_role: user.role === 'ADMIN' ? (user.admin_role || 'SUPER_ADMIN') : undefined,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
      },
      driverProfile,
    };
  }

  public generateToken(user: UserRow): string {
    const payload: JwtPayload = {
      userId: user.id,
      role: user.role,
      adminRole: user.role === 'ADMIN' ? (user.admin_role || 'SUPER_ADMIN') : undefined,
      email: user.email,
      phoneNumber: user.phone_number,
    };
    return jwt.sign(payload, ENV.JWT_SECRET, { expiresIn: '30d' });
  }

  public verifyToken(token: string): JwtPayload {
    return jwt.verify(token, ENV.JWT_SECRET) as JwtPayload;
  }

  // Dispatches 6-digit Email Verification OTP
  public async sendEmailVerificationOtp(email: string): Promise<{ success: boolean; message: string }> {
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    await db.saveEmailOtp(email, otp, 15);

    await resendService.sendEmail({
      to: email,
      subject: `Your Giga Ride Verification Code: ${otp}`,
      html: `
        <div style="font-family: Arial, sans-serif; background: #0A0F1D; color: #F8FAFC; padding: 28px; border-radius: 16px; max-width: 500px; margin: 0 auto;">
          <h2 style="color: #14B8A6; text-align: center; margin-bottom: 8px;">Email Verification</h2>
          <p style="color: #94A3B8; text-align: center; font-size: 13px;">Enter the code below to verify your email address on Giga Ride.</p>
          <div style="background: #131C31; border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; text-align: center; padding: 20px; margin: 24px 0;">
            <span style="font-size: 32px; font-weight: 900; letter-spacing: 8px; color: #10B981; font-family: monospace;">${otp}</span>
          </div>
          <p style="color: #64748B; font-size: 12px; text-align: center;">This code expires in 15 minutes. If you did not request this, please ignore this email.</p>
        </div>
      `,
    });

    return { success: true, message: 'Verification code sent to your email.' };
  }

  // Validates submitted Email Verification code
  public async verifyEmailOtp(email: string, otp: string): Promise<{ success: boolean; message: string }> {
    const isValid = await db.verifyEmailOtp(email, otp);
    if (!isValid) {
      return { success: false, message: 'Invalid or expired verification code.' };
    }
    return { success: true, message: 'Email address successfully verified.' };
  }

  // 1-Tap Passwordless Login / Verification via Phone OTP
  public async loginWithPhoneOtp(phoneNumber: string, otpCode: string): Promise<any> {
    const verifyResult = await twilioService.verifyOtp(phoneNumber, otpCode);
    if (!verifyResult.success) {
      throw new Error(verifyResult.message || 'Invalid or expired OTP code.');
    }

    // Check if user exists with this phone number
    const user = await db.findUserByPhone(phoneNumber);
    if (!user) {
      return {
        success: true,
        isNewUser: true,
        phoneNumber,
        message: 'Phone number verified. Please proceed to complete profile registration.',
      };
    }

    await db.markUserPhoneVerified(user.id);

    let driverProfile = undefined;
    let subscription = undefined;

    if (user.role === 'DRIVER') {
      driverProfile = await db.getDriverProfile(user.id);
      subscription = await db.getActiveDriverSubscription(user.id);
    }

    const token = this.generateToken(user);

    return {
      success: true,
      token,
      user: {
        id: user.id,
        role: user.role,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        isPhoneVerified: true,
        isEmailVerified: !!user.is_email_verified,
      },
      driverProfile,
      subscription,
      message: 'Logged in successfully via Phone OTP.',
    };
  }
}

export const authService = new AuthService();
