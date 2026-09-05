import { Router, Request, Response } from 'express';
import { premblyService } from './prembly.service';
import { requireAuth } from '../auth/auth.middleware';

export const kycRouter = Router();

/**
 * Verifies driver NIN with Prembly Identitypass.
 */
kycRouter.post('/verify-nin', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const user = (req as any).user;
    const { nin, firstName, lastName, dob } = req.body;

    if (!nin || !firstName || !lastName) {
      res.status(400).json({ success: false, message: 'nin, firstName, and lastName are required.' });
      return;
    }

    const result = await premblyService.verifyNIN(user.userId, nin, firstName, lastName, dob);
    res.json({ success: result.success, data: result });
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * Verifies driver's license with Prembly FRSC portal gateway.
 */
kycRouter.post('/verify-license', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const user = (req as any).user;
    const { licenseNumber, firstName, lastName, dob } = req.body;

    if (!licenseNumber || !firstName || !lastName) {
      res.status(400).json({ success: false, message: 'licenseNumber, firstName, and lastName are required.' });
      return;
    }

    const result = await premblyService.verifyDriversLicense(user.userId, licenseNumber, firstName, lastName, dob);
    res.json({ success: result.success, data: result });
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * Webhook for Prembly async verification callbacks.
 */
kycRouter.post('/prembly/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    console.log('[Prembly Webhook Received]', req.body);
    res.json({ status: true });
  } catch (err: any) {
    res.status(500).json({ status: false, error: err.message });
  }
});
