import { Router, Response } from 'express';
import { z } from 'zod';
import { adminService } from './admin.service';
import { AuthenticatedRequest, requireAuth, requireRole, requireAdminRole } from '../auth/auth.middleware';

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

// 3b. Driver Management: Quality & Strike Watchlist (Must be before /drivers/:id)
adminRouter.get(
  '/drivers/quality-watchlist',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT', 'KYC_OFFICER']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const watchlist = await adminService.getDriverQualityWatchlist();
      res.json({ success: true, data: watchlist });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

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

// 5. Driver Management: Approve or Reject KYC with reason (RBAC: KYC_OFFICER, SUPER_ADMIN)
adminRouter.post(
  '/drivers/:id/kyc-review',
  requireAdminRole(['SUPER_ADMIN', 'KYC_OFFICER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { status, rejectionReason } = kycReviewSchema.parse(req.body);
      const driverId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.reviewKyc(adminUser, driverId, status, rejectionReason, ip);
      res.status(200).json({
        success: true,
        message: `Driver KYC has been updated to ${status}.`,
        data: result,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

const updateDocsSchema = z.object({
  driver_license_expiry: z.string().optional(),
  insurance_expiry: z.string().optional(),
  road_worthiness_expiry: z.string().optional(),
  lasdri_card_number: z.string().optional(),
  lasdri_expiry: z.string().optional(),
});

// 6. Driver Management: Update Compliance Documents & Expiry Dates
adminRouter.put(
  '/drivers/:id/documents',
  requireAdminRole(['SUPER_ADMIN', 'KYC_OFFICER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const validated = updateDocsSchema.parse(req.body);
      const driverId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const updated = await adminService.updateDriverDocuments(adminUser, driverId, validated, ip);
      res.status(200).json({
        success: true,
        message: 'Driver documents updated successfully.',
        data: updated,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 7. Compliance Desk: Expiring or Expired Driver Documents
adminRouter.get(
  '/compliance/expiring',
  requireAdminRole(['SUPER_ADMIN', 'KYC_OFFICER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const daysAhead = req.query.days ? parseInt(String(req.query.days), 10) : 30;
      const drivers = await adminService.getExpiringComplianceDrivers(daysAhead);
      res.status(200).json({ success: true, data: drivers });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

const statusChangeSchema = z.object({
  accountStatus: z.enum(['ACTIVE', 'SUSPENDED', 'BANNED']),
});

// 8. Driver Management: Suspend / Ban / Reinstate (RBAC: SUPPORT_AGENT, SUPER_ADMIN)
adminRouter.post(
  '/drivers/:id/status',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { accountStatus } = statusChangeSchema.parse(req.body);
      const driverId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.setDriverAccountStatus(adminUser, driverId, accountStatus, ip);
      res.status(200).json({
        success: true,
        message: `Driver account status updated to ${accountStatus}.`,
        data: result,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 8b. Driver Management: Emergency Dispatch Unlock / Clear Lockout (RBAC: SUPPORT_AGENT, SUPER_ADMIN)
adminRouter.post(
  '/drivers/:id/unlock',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const driverId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.unlockDriver(adminUser, driverId, ip);
      res.status(200).json({
        success: true,
        message: 'Driver lockout cleared successfully. Driver can now receive dispatches.',
        data: result,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

const manualCreditSchema = z.object({
  ridesToAdd: z.number().int().positive(),
  reason: z.string().min(3),
});

// 9. Driver Management: Manual Ride Credit (RBAC: SUPPORT_AGENT, SUPER_ADMIN)
adminRouter.post(
  '/drivers/:id/credit-rides',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { ridesToAdd, reason } = manualCreditSchema.parse(req.body);
      const driverId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const sub = await adminService.manualCreditRides(adminUser, driverId, ridesToAdd, reason, ip);
      res.status(200).json({
        success: true,
        message: `Successfully credited ${ridesToAdd} rides to driver.`,
        data: sub,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

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

// 12. Resolve Emergency SOS Incident (RBAC: SUPPORT_AGENT, SUPER_ADMIN)
adminRouter.post(
  '/sos/:id/resolve',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { notes } = resolveSosSchema.parse(req.body);
      const id = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.resolveSosIncident(adminUser, id, notes, ip);
      res.status(200).json({ success: true, message: 'SOS Incident resolved.', data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 13. Dynamic Subscription Plans: List all plans
adminRouter.get('/plans', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const plans = await adminService.getSubscriptionPlans();
    res.status(200).json({ success: true, data: plans });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

const planCreateSchema = z.object({
  id: z.string().min(3),
  name: z.string().min(3),
  description: z.string(),
  plan_type: z.enum(['RIDE_COUNT', 'UNLIMITED']),
  total_rides: z.number().int().positive().nullable(),
  duration_days: z.number().int().positive(),
  price_kobo: z.number().int().positive(),
  is_active: z.boolean().default(true),
});

// 14. Dynamic Subscription Plans: Create New Plan (RBAC: SUPER_ADMIN)
adminRouter.post(
  '/plans',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const validated = planCreateSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const created = await adminService.createSubscriptionPlan(adminUser, validated, ip);
      res.status(201).json({ success: true, message: 'Subscription plan created.', data: created });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

const planUpdateSchema = z.object({
  name: z.string().min(3).optional(),
  description: z.string().optional(),
  plan_type: z.enum(['RIDE_COUNT', 'UNLIMITED']).optional(),
  total_rides: z.number().int().positive().nullable().optional(),
  duration_days: z.number().int().positive().optional(),
  price_kobo: z.number().int().positive().optional(),
  is_active: z.boolean().optional(),
});

// 15. Dynamic Subscription Plans: Update Plan (RBAC: SUPER_ADMIN)
adminRouter.put(
  '/plans/:id',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const validated = planUpdateSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const updated = await adminService.updateSubscriptionPlan(adminUser, id, validated, ip);
      res.status(200).json({ success: true, message: 'Subscription plan updated.', data: updated });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 16. Dynamic Subscription Plans: Delete Plan (RBAC: SUPER_ADMIN)
adminRouter.delete(
  '/plans/:id',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      await adminService.deleteSubscriptionPlan(adminUser, id, ip);
      res.status(200).json({ success: true, message: 'Subscription plan deleted.' });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 17. In-App Disputes: List all disputes
adminRouter.get(
  '/disputes',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const status = req.query.status as any;
      const disputes = await adminService.getDisputes(status);
      res.status(200).json({ success: true, data: disputes });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

const resolveDisputeSchema = z.object({
  notes: z.string().min(2),
  driverStrikeApplied: z.boolean().default(false),
  compensationRides: z.number().int().nonnegative().default(0),
});

// 18. In-App Disputes: Resolve dispute with notes, strikes, or compensation
adminRouter.post(
  '/disputes/:id/resolve',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const id = String(req.params.id);
      const { notes, driverStrikeApplied, compensationRides } = resolveDisputeSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const resolved = await adminService.resolveDispute(adminUser, id, notes, driverStrikeApplied, compensationRides, ip);
      res.status(200).json({ success: true, message: 'Dispute resolved.', data: resolved });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 19. High-Resolution GPS Breadcrumbs for Route Playback
adminRouter.get('/rides/:id/breadcrumbs', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rideId = String(req.params.id);
    const crumbs = await adminService.getRideBreadcrumbs(rideId);
    res.status(200).json({ success: true, data: crumbs });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 20. Official LASG Ministry of Transportation ₦50 Road Levy CSV Export
adminRouter.get(
  '/finance/lasg-mot-export',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const csvData = await adminService.exportLasgMotReportCsv();
      const filename = `LASG_MOT_Levy_Audit_${new Date().toISOString().slice(0, 10)}.csv`;

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.status(200).send(csvData);
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// 21. Dynamic Platform Settings & Petrol (PMS) Price Levers
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

adminRouter.put(
  '/settings',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const validated = settingsUpdateSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const updated = await adminService.updatePlatformSettings(adminUser, validated, ip);
      res.status(200).json({
        success: true,
        message: 'Platform economic settings updated successfully.',
        data: updated,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 22. Immutable Administrative Action Audit Logs
adminRouter.get(
  '/audit-logs',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const limit = req.query.limit ? parseInt(String(req.query.limit), 10) : 100;
      const action = req.query.action as string | undefined;
      const logs = await adminService.getAuditLogs(limit, action);
      res.status(200).json({ success: true, data: logs });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// 23. Passenger Directory
adminRouter.get('/passengers', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const passengers = await adminService.getPassengers();
    res.status(200).json({ success: true, data: passengers });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 24. Financial Transactions Audit Trail
adminRouter.get('/transactions', async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const txs = await adminService.getTransactions();
    res.status(200).json({ success: true, data: txs });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 25. FinTech & RegTech Integration Settings (Masked)
adminRouter.get(
  '/settings/integrations',
  requireAdminRole(['SUPER_ADMIN']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const settings = await adminService.getIntegrationSettings();
      res.status(200).json({ success: true, data: settings });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// 26. Update FinTech & RegTech Integration Settings
adminRouter.put(
  '/settings/integrations',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;
      const updated = await adminService.updateIntegrationSettings(adminUser, req.body, ip);
      res.status(200).json({ success: true, message: 'Integration settings updated successfully.', data: updated });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 27. Test Resend Email Dispatch
adminRouter.post(
  '/integrations/test-email',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { toEmail } = req.body;
      const { resendService } = await import('../notifications/resend.service');
      const target = toEmail || req.user!.email;
      const result = await resendService.sendEmail({
        to: target,
        subject: 'Giga Ride - Resend Integration Test',
        html: '<div style="font-family: Arial; padding: 20px; background: #0F172A; color: #FFF; border-radius: 12px;"><h2 style="color: #10B981;">✓ Resend API Integration Verified</h2><p>Your Giga Ride transactional email gateway is operating with 100% fidelity.</p></div>',
      });
      res.json({ success: true, message: `Test email dispatched to ${target}`, result });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// 28. Test Twilio SMS Dispatch
adminRouter.post(
  '/integrations/test-sms',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { phoneNumber } = req.body;
      const { twilioService } = await import('../notifications/twilio.service');
      const target = phoneNumber || '08012345678';
      const result = await twilioService.sendOtp(target);
      res.json({ success: true, message: `Test SMS dispatched to ${target}`, result });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// Passenger Commuter Passes (Giga Pass)
const createRiderPassSchema = z.object({
  rider_id: z.string(),
  pass_name: z.string().min(2),
  discount_percent: z.number().min(1).max(100),
  max_discount_per_ride_ngn: z.number().positive(),
  rides_remaining: z.number().int().positive(),
  corridor: z.string().optional(),
  duration_days: z.number().int().positive().optional().default(30),
  price_kobo: z.number().int().positive(),
});

adminRouter.get(
  '/passengers/commute-passes',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN', 'SUPPORT_AGENT']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const passes = await adminService.getAllRiderPasses();
      res.json({ success: true, data: passes });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/passengers/commute-passes',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const payload = createRiderPassSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const pass = await adminService.createRiderPass(adminUser, payload, ip);
      res.status(201).json({ success: true, message: 'Passenger commute pass issued successfully.', data: pass });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 29. Passenger Governance: Update Account Status
const passengerStatusSchema = z.object({
  status: z.enum(['ACTIVE', 'SUSPENDED', 'BANNED']),
});
adminRouter.post(
  '/passengers/:id/status',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { status } = passengerStatusSchema.parse(req.body);
      const passengerId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.setPassengerStatus(adminUser, passengerId, status, ip);
      res.json({ success: true, message: `Passenger status updated to ${status}.`, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 30. Passenger Governance: Manual Goodwill Wallet Credit
const passengerCreditSchema = z.object({
  amountNgn: z.number().positive(),
  reason: z.string().min(3),
});
adminRouter.post(
  '/passengers/:id/credit-wallet',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { amountNgn, reason } = passengerCreditSchema.parse(req.body);
      const passengerId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.creditPassengerWallet(adminUser, passengerId, amountNgn, reason, ip);
      res.json({ success: true, message: `Successfully credited ₦${amountNgn.toLocaleString()} to passenger wallet.`, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 31. Ride Explorer & Telemetry: List Historical Rides
adminRouter.get('/rides', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const status = req.query.status ? String(req.query.status) : undefined;
    const search = req.query.search ? String(req.query.search) : undefined;
    const limit = req.query.limit ? parseInt(String(req.query.limit), 10) : 100;

    const rides = await adminService.getAllRides({ status, search, limit });
    res.json({ success: true, data: rides });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Live Demand Heatmaps & GPS Surge Clusters
adminRouter.get(
  '/rides/demand-heatmap',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN', 'KYC_OFFICER', 'SUPPORT_AGENT']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const heatmap = await adminService.getDemandHeatmap();
      res.json({ success: true, data: heatmap });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// Scheduled Airport & Interstate Dispatch Desk
adminRouter.get(
  '/rides/scheduled',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const scheduled = await adminService.getScheduledRides();
      res.json({ success: true, data: scheduled });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// Assign Driver to Scheduled Ride
adminRouter.post(
  '/rides/:id/assign-driver',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { driverId } = req.body;
      if (!driverId) {
        res.status(400).json({ success: false, message: 'driverId is required' });
        return;
      }
      const rideId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const updated = await adminService.assignDriverToScheduledRide(adminUser, rideId, String(driverId), ip);
      res.json({ success: true, message: 'Driver successfully assigned to scheduled trip.', data: updated });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 32. Ride Explorer: Fetch GPS Breadcrumbs for Route Replay
adminRouter.get('/rides/:id/breadcrumbs', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rideId = String(req.params.id);
    const breadcrumbs = await adminService.getRideBreadcrumbs(rideId);
    res.json({ success: true, data: breadcrumbs });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 33. Ride Explorer: Emergency Admin Trip Cancellation
const cancelRideSchema = z.object({
  reason: z.string().min(3),
});
adminRouter.post(
  '/rides/:id/cancel',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { reason } = cancelRideSchema.parse(req.body);
      const rideId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.cancelRideByAdmin(adminUser, rideId, reason, ip);
      res.json({ success: true, message: 'Ride has been cancelled by administrator.', data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 34. Staff & RBAC: List Staff Members
adminRouter.get(
  '/staff',
  requireAdminRole(['SUPER_ADMIN']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const staff = await adminService.getStaffUsers();
      res.json({ success: true, data: staff });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// 35. Staff & RBAC: Create / Invite New Staff
const createStaffSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  phone: z.string().min(7),
  password: z.string().min(6),
  admin_role: z.enum(['SUPER_ADMIN', 'FINANCE_ADMIN', 'KYC_OFFICER', 'SUPPORT_AGENT']),
});
adminRouter.post(
  '/staff',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const payload = createStaffSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.createStaffUser(adminUser, payload, ip);
      res.status(201).json({ success: true, message: 'Staff user created successfully.', data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 36. Staff & RBAC: Update Staff Role
const updateStaffRoleSchema = z.object({
  admin_role: z.enum(['SUPER_ADMIN', 'FINANCE_ADMIN', 'KYC_OFFICER', 'SUPPORT_AGENT']),
});
adminRouter.put(
  '/staff/:id/role',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { admin_role } = updateStaffRoleSchema.parse(req.body);
      const staffId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.updateStaffRole(adminUser, staffId, admin_role, ip);
      res.json({ success: true, message: 'Staff role updated.', data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 37. Staff & RBAC: Suspend / Reinstate Staff Member
const updateStaffStatusSchema = z.object({
  status: z.enum(['ACTIVE', 'SUSPENDED']),
});
adminRouter.post(
  '/staff/:id/status',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { status } = updateStaffStatusSchema.parse(req.body);
      const staffId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.setStaffStatus(adminUser, staffId, status, ip);
      res.json({ success: true, message: `Staff status updated to ${status}.`, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 38. Compliance Radar: Dispatch 1-Click Renewal Reminder
const complianceReminderSchema = z.object({
  docType: z.string().optional(),
});
adminRouter.post(
  '/compliance/:id/remind',
  requireAdminRole(['SUPER_ADMIN', 'KYC_OFFICER', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { docType } = complianceReminderSchema.parse(req.body || {});
      const driverId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.sendComplianceReminder(adminUser, driverId, docType, ip);
      res.json({ success: true, message: `Reminder successfully sent to ${result.driverName}.`, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 39. Fleet Broadcast & Announcements Engine
const broadcastSchema = z.object({
  title: z.string().min(3),
  message: z.string().min(5),
  target: z.enum(['ALL', 'DRIVERS', 'PASSENGERS']),
  severity: z.enum(['INFO', 'WARNING', 'CRITICAL']),
});
adminRouter.post(
  '/broadcast',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const alert = broadcastSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.broadcastFleetAlert(adminUser, alert, ip);
      res.json({ success: true, message: `Fleet alert dispatched to ${alert.target}.`, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// 40. FinTech Float & Reconciliation Desk
adminRouter.get(
  '/finance/reconciliation',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const report = await adminService.getFinancialReconciliation();
      res.json({ success: true, data: report });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 41. DRIVER PAYOUTS & SETTLEMENT DESK
// ==========================================
const payoutActionSchema = z.object({
  action: z.enum(['APPROVE', 'REJECT']),
  rejectionReason: z.string().optional(),
});

const driverPayoutRequestSchema = z.object({
  driverId: z.string(),
  amountNgn: z.number().positive(),
  bankName: z.string().min(2),
  accountNumber: z.string().min(10),
  accountName: z.string().min(2),
  bankCode: z.string().optional(),
});

adminRouter.get(
  '/payouts',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const status = req.query.status as 'PENDING' | 'APPROVED' | 'REJECTED' | undefined;
      const payouts = await adminService.getDriverPayouts(status);
      res.json({ success: true, data: payouts });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/payouts/request',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const payload = driverPayoutRequestSchema.parse(req.body);
      const payout = await adminService.createDriverPayout(payload);
      res.status(201).json({ success: true, message: 'Payout request initiated.', data: payout });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/payouts/:id/action',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { action, rejectionReason } = payoutActionSchema.parse(req.body);
      const payoutId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.processDriverPayout(adminUser, payoutId, action, rejectionReason, ip);
      res.json({
        success: true,
        message: action === 'APPROVE' ? 'Payout approved and NIP transfer dispatched.' : 'Payout rejected and virtual account credited back.',
        data: result,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 42. MULTI-CITY & SURCHARGES GEOFENCING
// ==========================================
const createCityZoneSchema = z.object({
  name: z.string().min(2),
  state: z.string().min(2),
  currency: z.string().optional(),
  petrol_price_ngn: z.number().nonnegative(),
  base_flag_fall_ngn: z.number().nonnegative(),
  per_km_rate_ngn: z.number().nonnegative(),
  per_minute_rate_ngn: z.number().nonnegative(),
  state_levy_ngn: z.number().nonnegative(),
  airport_surcharge_ngn: z.number().nonnegative(),
  toll_surcharge_ngn: z.number().nonnegative(),
  is_active: z.boolean().optional(),
});

const updateCityZoneSchema = z.object({
  name: z.string().optional(),
  state: z.string().optional(),
  currency: z.string().optional(),
  petrol_price_ngn: z.number().optional(),
  base_flag_fall_ngn: z.number().optional(),
  per_km_rate_ngn: z.number().optional(),
  per_minute_rate_ngn: z.number().optional(),
  state_levy_ngn: z.number().optional(),
  airport_surcharge_ngn: z.number().optional(),
  toll_surcharge_ngn: z.number().optional(),
  is_active: z.boolean().optional(),
});

adminRouter.get(
  '/cities',
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const cities = await adminService.getCityZones();
      res.json({ success: true, data: cities });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/cities',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const payload = createCityZoneSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const created = await adminService.createCityZone(adminUser, payload, ip);
      res.status(201).json({ success: true, message: 'City zone added.', data: created });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

adminRouter.put(
  '/cities/:id',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const updates = updateCityZoneSchema.parse(req.body);
      const cityId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const updated = await adminService.updateCityZone(adminUser, cityId, updates, ip);
      res.json({ success: true, message: 'City zone rates updated.', data: updated });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 43. PROMO CODES & MARKETING CAMPAIGNS
// ==========================================
const createPromoSchema = z.object({
  code: z.string().min(3),
  description: z.string().optional(),
  discount_type: z.enum(['FLAT', 'PERCENTAGE']),
  discount_value: z.number().positive(),
  max_discount_ngn: z.number().positive().optional(),
  max_uses: z.number().positive().optional(),
  city: z.string().optional(),
  expires_at: z.string(),
  is_active: z.boolean().optional(),
});

const validatePromoSchema = z.object({
  code: z.string().min(2),
  trip_fare_ngn: z.number().positive(),
});

adminRouter.get(
  '/promos',
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const promos = await adminService.getPromoCodes();
      res.json({ success: true, data: promos });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/promos',
  requireAdminRole(['SUPER_ADMIN', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const payload = createPromoSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const promo = await adminService.createPromoCode(adminUser, payload, ip);
      res.status(201).json({ success: true, message: 'Promo code created.', data: promo });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

adminRouter.delete(
  '/promos/:id',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const promoId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const result = await adminService.deletePromoCode(adminUser, promoId, ip);
      res.json({ success: true, message: 'Promo code deleted.', data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/promos/validate',
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { code, trip_fare_ngn } = validatePromoSchema.parse(req.body);
      const result = await adminService.validatePromoCode(code, trip_fare_ngn);
      res.json({ success: true, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);


// ==========================================
// 45. PAYSTACK DIRECT CARD REFUND DESK
// ==========================================
const refundSchema = z.object({
  reason: z.string().min(3),
});

adminRouter.post(
  '/transactions/:id/refund',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { reason } = refundSchema.parse(req.body);
      const txId = String(req.params.id);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const refunded = await adminService.refundPaymentTransaction(adminUser, txId, reason, ip);
      res.json({ success: true, message: 'Card transaction marked as refunded.', data: refunded });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 46. PHYSICAL VEHICLE HUB INSPECTION
// ==========================================
const vehicleInspectionSchema = z.object({
  driver_id: z.string(),
  hub_name: z.string().min(2),
  inspector_name: z.string().optional(),
  status: z.enum(['PASSED', 'FAILED', 'PENDING']),
  ac_functional: z.boolean(),
  tires_healthy: z.boolean(),
  exterior_clean: z.boolean(),
  lights_functional: z.boolean(),
  notes: z.string().optional(),
});

adminRouter.get(
  '/inspections',
  requireAdminRole(['SUPER_ADMIN', 'KYC_OFFICER', 'SUPPORT_AGENT']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const driverId = req.query.driver_id as string | undefined;
      const inspections = await adminService.getVehicleInspections(driverId);
      res.json({ success: true, data: inspections });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/inspections',
  requireAdminRole(['SUPER_ADMIN', 'KYC_OFFICER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const payload = vehicleInspectionSchema.parse(req.body);
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const inspection = await adminService.recordVehicleInspection(adminUser, payload, ip);
      res.status(201).json({ success: true, message: 'Vehicle hub inspection recorded.', data: inspection });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 47. DATABASE SNAPSHOTS & DISASTER RECOVERY
// ==========================================
adminRouter.get(
  '/backups',
  requireAdminRole(['SUPER_ADMIN']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const backups = await adminService.getBackupSnapshots();
      res.json({ success: true, data: backups });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

adminRouter.post(
  '/backups/generate',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;

      const snapshot = await adminService.createBackupSnapshot(adminUser, ip);
      res.status(201).json({ success: true, message: 'Disaster recovery snapshot created.', data: snapshot });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 48. SYSTEM INTEGRITY & FAILURE RADAR
// ==========================================
adminRouter.get(
  '/system/failure-radar',
  requireAdminRole(['SUPER_ADMIN', 'FINANCE_ADMIN', 'KYC_OFFICER', 'SUPPORT_AGENT']),
  async (_req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const radar = await adminService.getFailureRadarMetrics();
      res.status(200).json({ success: true, data: radar });
    } catch (error: any) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 49. PRODUCTION DATA PURGE & OVERHAUL
// ==========================================
adminRouter.post(
  '/system/purge-data',
  requireAdminRole(['SUPER_ADMIN']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const adminUser = { id: req.user!.userId, email: req.user!.email };
      const ip = req.ip || req.socket.remoteAddress;
      const { confirmationCode } = req.body;

      if (!confirmationCode) {
        res.status(400).json({ success: false, message: 'Confirmation code is required to execute system purge.' });
        return;
      }

      const result = await adminService.purgeSystemData(adminUser, confirmationCode, ip);
      res.status(200).json({
        success: true,
        message: 'System purge completed. All test and mock data wiped. Pristine production state restored.',
        data: result,
      });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

