import { RtcTokenBuilder, RtcRole } from 'agora-token';
import { db } from '../../database';

export class AgoraService {
  private defaultAppId = '57d797d4eb6143769bd02999aed126ad';
  private defaultAppCertificate = '1235f6d658a44ac3875adc71d0109dce';

  /**
   * Retrieves active Agora App ID & Certificate from DB settings or environment
   */
  public async getCredentials(): Promise<{ appId: string; appCertificate: string }> {
    const s = await db.getPlatformSettings();
    const appId = s.agora_app_id || process.env.AGORA_APP_ID || this.defaultAppId;
    const appCertificate = s.agora_app_certificate || process.env.AGORA_APP_CERTIFICATE || this.defaultAppCertificate;
    return { appId, appCertificate };
  }

  /**
   * Generate secure RTC Token for a Ride Audio Channel
   */
  public async generateRtcToken(
    channelName: string,
    uid: number = 0,
    role: number = RtcRole.PUBLISHER,
    expireSeconds: number = 3600
  ): Promise<{ token: string; appId: string; channelName: string; uid: number }> {
    const { appId, appCertificate } = await this.getCredentials();

    if (!appId) {
      throw new Error('Agora App ID is not configured.');
    }

    if (!appCertificate) {
      return {
        token: '',
        appId,
        channelName,
        uid,
      };
    }

    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expireSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      role,
      expireSeconds,
      expireSeconds
    );



    return {
      token,
      appId,
      channelName,
      uid,
    };
  }
}

export const agoraService = new AgoraService();
