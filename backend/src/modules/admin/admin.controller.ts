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
