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
  phoneNumber: z.string().min(8),
  email: z.string().email(),
  password: z.string().min(6),
  vehicleMake: z.string().nullable().optional(),
  vehicleModel: z.string().nullable().optional(),
  vehicleYear: z.union([z.number(), z.string()]).transform(v => typeof v === 'string' ? (parseInt(v, 10) || 2018) : (v || 2018)).nullable().optional(),
  licensePlate: z.string().nullable().optional(),
  vehicleColor: z.string().nullable().optional(),
  nin: z.string().nullable().optional(),
  bvn: z.string().nullable().optional(),
});

const loginSchema = z.object({
  identifier: z.string().min(3),
  password: z.string().min(6),
});

authRouter.post('/register', async (req, res: Response): Promise<void> => {
  try {
    const validated = registerSchema.parse(req.body);
    const result = await authService.register(validated as any);
    res.status(201).json({ success: true, data: result });
  } catch (error: any) {
    let errMsg = error.message || 'Registration failed';
    if (error.errors && Array.isArray(error.errors)) {
      errMsg = error.errors.map((e: any) => `${e.path?.join('.')}: ${e.message}`).join(', ');
    }
    console.error('[Registration Failed]', errMsg);
    res.status(400).json({ success: false, message: errMsg });
  }
});

authRouter.post('/login', async (req, res: Response): Promise<void> => {
  try {
    const validated = loginSchema.parse(req.body);
    const result = await authService.login(validated);
    res.status(200).json({ success: true, data: result });
  } catch (error: any) {
    res.status(error.requiresPhoneVerification ? 403 : 400).json({
      success: false,
      message: error.message || 'Login failed',
      requiresPhoneVerification: !!error.requiresPhoneVerification,
      phoneNumber: error.phoneNumber,
    });
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

// Password Recovery Routes
authRouter.post('/forgot-password', async (req, res: Response): Promise<void> => {
  try {
    const { identifier } = req.body;
    if (!identifier) {
      res.status(400).json({ success: false, message: 'Phone number or email is required.' });
      return;
    }
    const result = await authService.forgotPassword(identifier);
    res.status(200).json(result);
  } catch (err: any) {
    res.status(400).json({ success: false, message: err.message });
  }
});

authRouter.post('/reset-password', async (req, res: Response): Promise<void> => {
  try {
    const { phoneNumber, otpCode, newPassword } = req.body;
    if (!phoneNumber || !otpCode || !newPassword) {
      res.status(400).json({ success: false, message: 'phoneNumber, otpCode, and newPassword are required.' });
      return;
    }
    const result = await authService.resetPassword(phoneNumber, otpCode, newPassword);
    res.status(200).json(result);
  } catch (err: any) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// Pre-check phone or email availability to prevent duplicates early
authRouter.post('/check-availability', async (req, res: Response): Promise<void> => {
  try {
    const { phoneNumber, email } = req.body;
    const result = await authService.checkAvailability(phoneNumber, email);
    res.status(result.available ? 200 : 409).json(result);
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

authRouter.post('/send-otp', async (req, res: Response): Promise<void> => {
  try {
    const { phoneNumber, isSignUp, isLogin } = req.body;
    if (!phoneNumber) {
      res.status(400).json({ success: false, message: 'phoneNumber is required.' });
      return;
    }

    if (isSignUp) {
      const existing = await db.findUserByPhone(phoneNumber);
      if (existing) {
        res.status(409).json({
          success: false,
          code: 'ACCOUNT_EXISTS',
          message: 'This phone number is already registered with an active Giga Ride account. Please sign in instead.',
        });
        return;
      }
    } else if (isLogin) {
      const existing = await db.findUserByPhone(phoneNumber);
      if (!existing) {
        res.status(404).json({
          success: false,
          code: 'ACCOUNT_NOT_FOUND',
          message: 'No account found with this phone number. Please create an account.',
        });
        return;
      }
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
    const { email, isSignUp, isLogin } = req.body;
    if (!email || !email.includes('@')) {
      res.status(400).json({ success: false, message: 'A valid email address is required.' });
      return;
    }

    if (isSignUp) {
      const existing = await db.findUserByEmail(email);
      if (existing) {
        res.status(409).json({
          success: false,
          code: 'ACCOUNT_EXISTS',
          message: 'This email address is already registered with an active Giga Ride account. Please sign in instead.',
        });
        return;
      }
    } else if (isLogin) {
      const existing = await db.findUserByEmail(email);
      if (!existing) {
        res.status(404).json({
          success: false,
          code: 'ACCOUNT_NOT_FOUND',
          message: 'No account found with this email address. Please create an account.',
        });
        return;
      }
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

// 1-Tap Passwordless Login via Email OTP
authRouter.post('/login-email-otp', async (req, res: Response): Promise<void> => {
  try {
    const { email, otpCode } = req.body;
    if (!email || !otpCode) {
      res.status(400).json({ success: false, message: 'email and otpCode are required.' });
      return;
    }
    const result = await authService.loginWithEmailOtp(email, otpCode);
    res.json({ success: true, data: result, ...result });
  } catch (err: any) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// 1-Tap Google Sign-In (Creates or logs into account seamlessly)
authRouter.post('/google-login', async (req, res: Response): Promise<void> => {
  try {
    const { email, fullName, googleId, photoUrl, role } = req.body;
    if (!email) {
      res.status(400).json({ success: false, message: 'Google account email is required.' });
      return;
    }
    const result = await authService.loginWithGoogle({
      email,
      fullName,
      googleId,
      photoUrl,
      role: role || 'PASSENGER',
    });
    res.json({ success: true, data: result, ...result });
  } catch (err: any) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// Self-Service Account Deletion (Apple App Store Guideline 5.1.1(v) & Google Play Compliance)
authRouter.post('/delete-account', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user!.userId;
    const success = await db.deleteUserAccount(userId);
    if (!success) {
      res.status(404).json({ success: false, message: 'Account not found.' });
      return;
    }
    res.status(200).json({
      success: true,
      message: 'Account successfully deactivated and personal identifying data anonymized.'
    });
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

