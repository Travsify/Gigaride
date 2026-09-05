import { Router, Response } from 'express';
import { z } from 'zod';
import { adminService } from './admin.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';

export const adminRouter = Router();

// Protect all admin routes with JWT and ADMIN role
adminRouter.use(requireAuth);
adminRouter.use(requireRole(['ADMIN']));

// 1. Executive Operations Analytics & Lagos MOT levy audit
adminRouter.get('/analytics', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const stats = await adminService.getAnalytics();
    res.status(200).json({ success: true, data: stats });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 2. Driver Management: List with filters
adminRouter.get('/drivers', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const filter = (req.query.filter as any) || 'ALL';
    const drivers = await adminService.getDrivers(filter);
    res.status(200).json({ success: true, data: drivers });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 3. Driver Management: Pending KYC list (backward compatibility)
adminRouter.get('/drivers/pending-kyc', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const drivers = await adminService.getDrivers('PENDING_KYC');
    res.status(200).json({ success: true, data: drivers });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 4. Driver Management: Full 360-degree Dossier
adminRouter.get('/drivers/:id', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const driverId = String(req.params.id);
    const dossier = await adminService.getDriverDossier(driverId);
    res.status(200).json({ success: true, data: dossier });
  } catch (error: any) {
    res.status(404).json({ success: false, message: error.message });
  }
});

const kycReviewSchema = z.object({
  status: z.enum(['APPROVED', 'REJECTED']),
  rejectionReason: z.string().optional(),
});

// 5. Driver Management: Approve or Reject KYC with reason
adminRouter.post('/drivers/:id/kyc-review', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { status, rejectionReason } = kycReviewSchema.parse(req.body);
    const driverId = String(req.params.id);
    const result = await adminService.reviewKyc(driverId, status, rejectionReason);
    res.status(200).json({
      success: true,
      message: `Driver KYC has been updated to ${status}.`,
      data: result,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

const statusChangeSchema = z.object({
  accountStatus: z.enum(['ACTIVE', 'SUSPENDED', 'BANNED']),
});

// 6. Driver Management: Suspend / Ban / Reinstate
adminRouter.post('/drivers/:id/status', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { accountStatus } = statusChangeSchema.parse(req.body);
    const driverId = String(req.params.id);
    const result = await adminService.setDriverAccountStatus(driverId, accountStatus);
    res.status(200).json({
      success: true,
      message: `Driver account status updated to ${accountStatus}.`,
      data: result,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

const manualCreditSchema = z.object({
  ridesToAdd: z.number().int().positive(),
  reason: z.string().min(3),
});

// 7. Driver Management: Manual Ride Credit (Customer Support / Bank Transfer)
adminRouter.post('/drivers/:id/credit-rides', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { ridesToAdd, reason } = manualCreditSchema.parse(req.body);
    const driverId = String(req.params.id);
    const adminId = req.user!.userId;
    const sub = await adminService.manualCreditRides(adminId, driverId, ridesToAdd, reason);
    res.status(200).json({
      success: true,
      message: `Successfully credited ${ridesToAdd} rides to driver.`,
      data: sub,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// 8. Driver Management: Ride Credit Audit Trail
adminRouter.get('/drivers/:id/credit-history', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const driverId = String(req.params.id);
    const history = await adminService.getCreditAudits(driverId);
    res.status(200).json({ success: true, data: history });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 9. Dispatch Surveillance: Live Active Rides
adminRouter.get('/rides/active', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rides = await adminService.getActiveRides();
    res.status(200).json({ success: true, data: rides });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 10. Dispatch Surveillance: Live Fleet Radar (Online drivers & locations)
adminRouter.get('/fleet/live', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const fleet = await adminService.getLiveFleet();
    res.status(200).json({ success: true, data: fleet });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 11. Emergency SOS Incident Console
adminRouter.get('/sos', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const status = req.query.status as any;
    const incidents = await adminService.getSosIncidents(status);
    res.status(200).json({ success: true, data: incidents });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

const resolveSosSchema = z.object({
  notes: z.string().min(2),
});

// 12. Resolve Emergency SOS Incident
adminRouter.post('/sos/:id/resolve', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { notes } = resolveSosSchema.parse(req.body);
    const id = String(req.params.id);
    const result = await adminService.resolveSosIncident(id, notes);
    res.status(200).json({ success: true, message: 'SOS Incident resolved.', data: result });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// 13. Dynamic Platform Settings & Petrol (PMS) Price Levers
adminRouter.get('/settings', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const settings = await adminService.getPlatformSettings();
    res.status(200).json({ success: true, data: settings });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

const settingsUpdateSchema = z.object({
  petrol_price_ngn: z.number().positive().optional(),
  base_flag_fall_ngn: z.number().positive().optional(),
  per_km_rate_ngn: z.number().positive().optional(),
  per_minute_rate_ngn: z.number().positive().optional(),
  lagos_mot_levy_ngn: z.number().positive().optional(),
  welcome_bonus_rides: z.number().int().nonnegative().optional(),
  search_radius_km: z.number().positive().optional(),
});

adminRouter.put('/settings', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const validated = settingsUpdateSchema.parse(req.body);
    const updated = await adminService.updatePlatformSettings(validated);
    res.status(200).json({
      success: true,
      message: 'Platform economic settings updated successfully.',
      data: updated,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// 14. Passenger Directory
adminRouter.get('/passengers', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const passengers = await adminService.getPassengers();
    res.status(200).json({ success: true, data: passengers });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 15. Financial Transactions Audit Trail
adminRouter.get('/transactions', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const txs = await adminService.getTransactions();
    res.status(200).json({ success: true, data: txs });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});
