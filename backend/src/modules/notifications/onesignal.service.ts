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
   * Helper: Dispatches match alert to passenger when driver is assigned.
   */
  public async sendDriverAssignedToPassenger(
    passengerId: string,
    driverName: string,
    vehicleInfo: string,
    etaMinutes: number,
    rideId: string
  ) {
    return this.sendPush({
      userIds: [passengerId],
      heading: '🚗 Driver Confirmed & On the Way!',
      content: `${driverName} (${vehicleInfo}) is en route to your pickup. ETA ~${etaMinutes} mins.`,
      data: { type: 'DRIVER_ASSIGNED', rideId },
    });
  }

  /**
   * Helper: Dispatches approaching alert when driver is within ~500m of pickup.
   */
  public async sendDriverApproachingAlert(
    passengerId: string,
    driverName: string,
    landmarkName: string | null,
    rideId: string
  ) {
    const nearText = landmarkName ? ` passing ${landmarkName}` : '';
    return this.sendPush({
      userIds: [passengerId],
      heading: '⚡ Driver is Approaching Pickup!',
      content: `${driverName} is 2 mins away${nearText}. Please head out to your pickup spot.`,
      data: { type: 'DRIVER_APPROACHING', rideId },
    });
  }

  /**
   * Helper: Dispatches arrival alert when driver arrives at pickup.
   */
  public async sendDriverArrivedAlert(
    passengerId: string,
    driverName: string,
    vehicleInfo: string,
    rideId: string
  ) {
    return this.sendPush({
      userIds: [passengerId],
      heading: '📍 Driver Has Arrived!',
      content: `${driverName} is waiting outside in ${vehicleInfo}. Free wait time: 3 mins.`,
      data: { type: 'DRIVER_ARRIVED', rideId },
    });
  }

  /**
   * Helper: Dispatches trip started alert.
   */
  public async sendTripStartedAlert(
    passengerId: string,
    dropoffAddress: string,
    rideId: string
  ) {
    return this.sendPush({
      userIds: [passengerId],
      heading: 'Trip in Progress 🚗',
      content: `En route to ${dropoffAddress}. Sit back and enjoy your trip!`,
      data: { type: 'TRIP_STARTED', rideId },
    });
  }

  /**
   * Helper: Dispatches trip completed alert.
   */
  public async sendTripCompletedAlert(
    passengerId: string,
    agreedFareNgn: number,
    dropoffAddress: string,
    rideId: string
  ) {
    return this.sendPush({
      userIds: [passengerId],
      heading: '🏁 Trip Completed! Receipt Ready',
      content: `You arrived at ${dropoffAddress}. ₦${agreedFareNgn.toLocaleString('en-NG')} settled with 0% commission.`,
      data: { type: 'TRIP_COMPLETED', rideId, fareNgn: agreedFareNgn },
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

  /**
   * Helper: Dispatches wait time started alert to passenger.
   */
  public async sendWaitTimeStartedAlert(
    passengerId: string,
    graceMins: number,
    ratePerMin: number,
    rideId: string
  ) {
    return this.sendPush({
      userIds: [passengerId],
      heading: '⏱️ Driver Started Wait Time',
      content: `Driver has parked at stopover. First ${graceMins} minutes are free, then ₦${ratePerMin}/min.`,
      data: { type: 'WAIT_TIME_STARTED', rideId },
    });
  }
}

export const oneSignalService = new OneSignalService();
