import axios from 'axios';
import { db } from '../../database';
import { ENV } from '../../config/env';

export interface SendPushNotificationPayload {
  userIds?: string[];
  segments?: string[];
  heading: string;
  content: string;
  data?: Record<string, any>;
}

export class OneSignalService {
  private baseUrl = 'https://onesignal.com/api/v1/notifications';

  private async getCredentials(): Promise<{ appId: string; restApiKey: string }> {
    const settings = await db.getPlatformSettings();
    const appId = settings.onesignal_app_id || ENV.ONESIGNAL_APP_ID;
    const restApiKey = settings.onesignal_rest_api_key || ENV.ONESIGNAL_REST_API_KEY;
    return { appId, restApiKey };
  }

  /**
   * Dispatches a push notification via OneSignal REST API.
   */
  public async sendPush(payload: SendPushNotificationPayload): Promise<{ success: boolean; id?: string; error?: string }> {
    const { appId, restApiKey } = await this.getCredentials();

    if (!appId || !restApiKey || restApiKey.includes('mock')) {
      console.log(`[OneSignal Simulation] Heading: "${payload.heading}" | Content: "${payload.content}"`);
      return { success: true, id: `sim_onesignal_${Date.now()}` };
    }

    try {
      const body: any = {
        app_id: appId,
        headings: { en: payload.heading },
        contents: { en: payload.content },
      };

      if (payload.userIds && payload.userIds.length > 0) {
        body.include_aliases = { external_id: payload.userIds };
        body.include_external_user_ids = payload.userIds;
        body.target_channel = 'push';
      } else if (payload.segments && payload.segments.length > 0) {
        body.included_segments = payload.segments;
      } else {
        body.included_segments = ['Subscribed Users'];
      }

      body.priority = 10;
      body.android_accent_color = 'FF0F766E';
      body.android_channel_id = 'giga_dispatch_channel';
      body.android_sound = 'notification';
      body.ios_sound = 'notification.wav';

      if (payload.data) {
        body.data = payload.data;
      }

      const response = await axios.post(this.baseUrl, body, {
        headers: {
          Authorization: `Key ${restApiKey}`,
          'Content-Type': 'application/json',
        },
      });

      return { success: true, id: response.data.id };
    } catch (err: any) {
      console.error('[OneSignal Push Error]', err.response?.data || err.message);
      return { success: false, error: err.response?.data?.errors?.[0] || err.message };
    }
  }

  /**
   * Helper: Dispatches real-time bid alert to passenger.
   */
  public async sendBidAlertToPassenger(passengerId: string, driverName: string, fareNgn: number, rideId: string) {
    return this.sendPush({
      userIds: [passengerId],
      heading: '🚖 New Driver Offer Received!',
      content: `${driverName} offered ₦${fareNgn.toLocaleString('en-NG')} for your ride. Tap to review.`,
      data: { type: 'NEW_BID', rideId },
    });
  }

  /**
   * Helper: Dispatches match confirmation to driver.
   */
  public async sendMatchAlertToDriver(driverId: string, passengerName: string, pickupAddress: string, rideId: string) {
    return this.sendPush({
      userIds: [driverId],
      heading: '🎉 Offer Accepted! Head to Pickup',
      content: `${passengerName} accepted your offer. Pickup: ${pickupAddress}`,
      data: { type: 'BID_ACCEPTED', rideId },
    });
  }

  /**
   * Helper: Dispatches SOS security broadcast to response center and contacts.
   */
  public async sendSosAlert(riderName: string, carPlate: string, trackingUrl: string) {
    return this.sendPush({
      segments: ['Admin Dispatch', 'Security Operations'],
      heading: '🚨 SOS ALERT TRIGGERED',
      content: `Emergency on ride for ${riderName} in vehicle ${carPlate}. Live tracking active.`,
      data: { type: 'SOS_INCIDENT', trackingUrl },
    });
  }
}

export const oneSignalService = new OneSignalService();
