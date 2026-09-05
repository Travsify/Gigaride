import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { db, UserRow } from '../../database';
import { ENV } from '../../config/env';
import { AuthResponse, JwtPayload, LoginDto, RegisterUserDto } from './auth.types';

export class AuthService {
  public async register(dto: RegisterUserDto): Promise<AuthResponse> {
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

    // 5. Generate token
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

    if (!user) {
      throw new Error('Invalid phone/email or password.');
    }

    // 2. Verify password
    const isMatch = await bcrypt.compare(dto.password, user.password_hash);
    if (!isMatch) {
      throw new Error('Invalid phone/email or password.');
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
      email: user.email,
      phoneNumber: user.phone_number,
    };
    return jwt.sign(payload, ENV.JWT_SECRET, { expiresIn: '30d' });
  }

  public verifyToken(token: string): JwtPayload {
    return jwt.verify(token, ENV.JWT_SECRET) as JwtPayload;
  }
}

export const authService = new AuthService();
