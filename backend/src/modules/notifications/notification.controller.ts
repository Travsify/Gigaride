import { Router, Response } from 'express';
import { db } from '../../database';
import { AuthenticatedRequest, requireAuth } from '../auth/auth.middleware';

export const notificationRouter = Router();

/**
 * GET /api/notifications
 * Retrieves list of in-app notifications for the authenticated user and unread count.
 */
notificationRouter.get(
  '/',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.userId;
      const limit = parseInt(req.query.limit as string, 10) || 30;
      const notifications = await db.getUserNotifications(userId, limit);
      const unreadCount = await db.getUnreadNotificationsCount(userId);

      res.status(200).json({
        success: true,
        data: {
          notifications,
          unreadCount,
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

/**
 * PATCH /api/notifications/:id/read
 * Marks a specific notification as read.
 */
notificationRouter.patch(
  '/:id/read',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const notificationId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const userId = req.user!.userId;
      const success = await db.markNotificationAsRead(notificationId, userId);

      if (!success) {
        res.status(404).json({ success: false, message: 'Notification not found' });
        return;
      }

      res.status(200).json({ success: true, message: 'Notification marked as read' });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

/**
 * PATCH /api/notifications/read-all
 * Marks all notifications for the user as read.
 */
notificationRouter.patch(
  '/read-all',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.userId;
      const count = await db.markAllNotificationsAsRead(userId);

      res.status(200).json({
        success: true,
        message: `${count} notifications marked as read`,
        count,
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);
