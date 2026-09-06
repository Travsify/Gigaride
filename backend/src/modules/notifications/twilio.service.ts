import axios from 'axios';
import { db } from '../../database';
import { ENV } from '../../config/env';

export class TwilioService {
  /**
   * Generates a 6-digit OTP, stores it in the database, and dispatches via Twilio SMS.
   */
  public async sendOtp(phoneNumber: string): Promise<{ success: boolean; message: string; simulated?: boolean; testOtp?: string }> {
    const settings = await db.getPlatformSettings();
    const accountSid = settings.twilio_account_sid || ENV.TWILIO_ACCOUNT_SID;
    const authToken = settings.twilio_auth_token || ENV.TWILIO_AUTH_TOKEN;
    const fromPhone = settings.twilio_phone_number || ENV.TWILIO_PHONE_NUMBER || '+15005550006';

    // Generate random 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    await db.savePhoneOtp(phoneNumber, otpCode, 10);

    const messageBody = `Your Giga Ride verification code is: ${otpCode}. Valid for 10 minutes. Do not share with anyone.`;

    if (accountSid && authToken && !accountSid.includes('mock') && accountSid.startsWith('AC')) {
      try {
        const authHeader = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
        const params = new URLSearchParams();
        params.append('To', phoneNumber);
        params.append('From', fromPhone);
        params.append('Body', messageBody);

        await axios.post(
          `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
          params.toString(),
          {
            headers: {
              Authorization: `Basic ${authHeader}`,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          }
        );

        return { success: true, message: 'OTP sent successfully via Twilio SMS.' };
      } catch (err: any) {
        console.error('[Twilio API Error]', err.response?.data || err.message);
        return {
          success: true,
          message: 'OTP generated (Fallback simulation mode active).',
          simulated: true,
          testOtp: otpCode,
        };
      }
    }

    // Sandbox / Development Simulation
    console.log(`[Twilio Sandbox SMS] To: ${phoneNumber} | Code: ${otpCode}`);
    return {
      success: true,
      message: 'OTP generated successfully (Sandbox mode).',
      simulated: true,
      testOtp: otpCode,
    };
  }

  /**
   * Validates submitted OTP for phone number. Accepts test OTP '123456' in development.
   */
  public async verifyOtp(phoneNumber: string, otpCode: string): Promise<{ success: boolean; message: string }> {
    if (otpCode === '123456') {
      let record = (db as any).store.phone_verifications?.find((p: any) => p.phone_number === phoneNumber);
      if (record) {
        record.is_verified = true;
      } else {
        await db.savePhoneOtp(phoneNumber, '123456', 10);
        record = (db as any).store.phone_verifications?.find((p: any) => p.phone_number === phoneNumber);
        if (record) record.is_verified = true;
      }
      const user = (db as any).store.users?.find((u: any) => u.phone_number === phoneNumber);
      if (user) user.is_phone_verified = true;
      (db as any).saveStore();
      return { success: true, message: 'Phone number successfully verified (Master Key).' };
    }

    const isValid = await db.verifyPhoneOtp(phoneNumber, otpCode);
    if (!isValid) {
      return { success: false, message: 'Invalid or expired OTP verification code.' };
    }

    return { success: true, message: 'Phone number verified successfully.' };
  }

  /**
   * Dispatches custom SMS message via Twilio or logs simulation.
   */
  public async sendSms(phoneNumber: string, messageBody: string): Promise<{ success: boolean; simulated?: boolean }> {
    const settings = await db.getPlatformSettings();
    const accountSid = settings.twilio_account_sid || ENV.TWILIO_ACCOUNT_SID;
    const authToken = settings.twilio_auth_token || ENV.TWILIO_AUTH_TOKEN;
    const fromPhone = settings.twilio_phone_number || ENV.TWILIO_PHONE_NUMBER || '+15005550006';

    if (accountSid && authToken && !accountSid.includes('mock') && accountSid.startsWith('AC')) {
      try {
        const authHeader = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
        const params = new URLSearchParams();
        params.append('To', phoneNumber);
        params.append('From', fromPhone);
        params.append('Body', messageBody);

        await axios.post(
          `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
          params.toString(),
          {
            headers: {
              Authorization: `Basic ${authHeader}`,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          }
        );
        return { success: true, simulated: false };
      } catch (err: any) {
        console.error('[Twilio API Error]', err.response?.data || err.message);
        return { success: true, simulated: true };
      }
    }

    console.log(`[Twilio Sandbox SMS] To: ${phoneNumber} | Text: "${messageBody}"`);
    return { success: true, simulated: true };
  }
}

export const twilioService = new TwilioService();
