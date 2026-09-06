import { Router, Response } from 'express';
import { z } from 'zod';
import { authService } from './auth.service';
import { AuthenticatedRequest, requireAuth } from './auth.middleware';
import { db } from '../../database';
import { twilioService } from '../notifications/twilio.service';

export const authRouter = Router();

const registerSchema = z.object({
  role: z.enum(['PASSENGER', 'DRIVER', 'ADMIN']),
  fullName: z.string().min(2),
  phoneNumber: z.string().min(10),
  email: z.string().email(),
  password: z.string().min(6),
  vehicleMake: z.string().optional(),
  vehicleModel: z.string().optional(),
  vehicleYear: z.number().optional(),
  licensePlate: z.string().optional(),
  vehicleColor: z.string().optional(),
  nin: z.string().optional(),
  bvn: z.string().optional(),
});

const loginSchema = z.object({
  identifier: z.string().min(3),
  password: z.string().min(6),
});

authRouter.post('/register', async (req, res: Response): Promise<void> => {
  try {
    const validated = registerSchema.parse(req.body);
    const result = await authService.register(validated);
    res.status(201).json({ success: true, data: result });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message || 'Registration failed' });
  }
});

authRouter.post('/login', async (req, res: Response): Promise<void> => {
  try {
    const validated = loginSchema.parse(req.body);
    const result = await authService.login(validated);
    res.status(200).json({ success: true, data: result });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message || 'Login failed' });
  }
});

authRouter.get('/me', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const user = await db.findUserById(req.user!.userId);
    if (!user) {
      res.status(404).json({ success: false, message: 'User not found' });
      return;
    }

    let driverProfile = undefined;
    let subscription = undefined;

    if (user.role === 'DRIVER') {
      driverProfile = await db.getDriverProfile(user.id);
      subscription = await db.getActiveDriverSubscription(user.id);
    }

    res.status(200).json({
      success: true,
      data: {
        id: user.id,
        role: user.role,
        fullName: user.full_name,
        phoneNumber: user.phone_number,
        email: user.email,
        driverProfile,
        subscription,
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

authRouter.post('/send-otp', async (req, res: Response): Promise<void> => {
  try {
    const { phoneNumber } = req.body;
    if (!phoneNumber) {
      res.status(400).json({ success: false, message: 'phoneNumber is required.' });
      return;
    }
    const result = await twilioService.sendOtp(phoneNumber);
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

authRouter.post('/verify-otp', async (req, res: Response): Promise<void> => {
  try {
    const { phoneNumber, otpCode } = req.body;
    if (!phoneNumber || !otpCode) {
      res.status(400).json({ success: false, message: 'phoneNumber and otpCode are required.' });
      return;
    }
    // Authenticates user directly if they already exist, or validates phone for registration
    const result = await authService.loginWithPhoneOtp(phoneNumber, otpCode);
    res.status(200).json(result);
  } catch (err: any) {
    res.status(400).json({ success: false, message: err.message });
  }
});


// Dispatches 6-digit Email Verification OTP via Resend
authRouter.post('/send-email-otp', async (req, res: Response): Promise<void> => {
  try {
    const { email } = req.body;
    if (!email || !email.includes('@')) {
      res.status(400).json({ success: false, message: 'A valid email address is required.' });
      return;
    }
    const result = await authService.sendEmailVerificationOtp(email);
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Verifies Email OTP
authRouter.post('/verify-email', async (req, res: Response): Promise<void> => {
  try {
    const { email, otpCode } = req.body;
    if (!email || !otpCode) {
      res.status(400).json({ success: false, message: 'email and otpCode are required.' });
      return;
    }
    const result = await authService.verifyEmailOtp(email, otpCode);
    res.status(result.success ? 200 : 400).json(result);
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 1-Tap Passwordless Login via Phone OTP
authRouter.post('/login-otp', async (req, res: Response): Promise<void> => {
  try {
    const { phoneNumber, otpCode } = req.body;
    if (!phoneNumber || !otpCode) {
      res.status(400).json({ success: false, message: 'phoneNumber and otpCode are required.' });
      return;
    }
    const result = await authService.loginWithPhoneOtp(phoneNumber, otpCode);
    res.json(result);
  } catch (err: any) {
    res.status(400).json({ success: false, message: err.message });
  }
});
