import axios from 'axios';
import { db } from '../../database';
import { ENV } from '../../config/env';

export interface SendEmailPayload {
  to: string | string[];
  subject: string;
  html: string;
  text?: string;
}

export class ResendService {
  private baseUrl = 'https://api.resend.com/emails';

  /**
   * Dispatches transactional email via Resend REST API or logs simulated delivery.
   */
  public async sendEmail(payload: SendEmailPayload): Promise<{ success: boolean; messageId: string; simulated?: boolean }> {
    const settings = await db.getPlatformSettings();
    const apiKey = settings.resend_api_key || ENV.RESEND_API_KEY;
    let fromEmail = settings.resend_from_email || ENV.RESEND_FROM_EMAIL || 'info@getgigaride.com';
    if (!fromEmail || fromEmail.includes('gigaride.ng')) {
      fromEmail = 'info@getgigaride.com';
    }

    if (apiKey && !apiKey.includes('mock') && apiKey.startsWith('re_')) {
      try {
        const response = await axios.post(
          this.baseUrl,
          {
            from: `Giga Ride <${fromEmail}>`,
            to: Array.isArray(payload.to) ? payload.to : [payload.to],
            subject: payload.subject,
            html: payload.html,
            text: payload.text || payload.subject,
          },
          {
            headers: {
              Authorization: `Bearer ${apiKey}`,
              'Content-Type': 'application/json',
            },
          }
        );
        return { success: true, messageId: response.data.id, simulated: false };
      } catch (err: any) {
        const errMsg = err.response?.data?.message || err.message;
        // If custom domain is pending DNS verification, auto-fallback to Resend verified sender
        if (errMsg && errMsg.includes('domain is not verified')) {
          try {
            const fallbackResponse = await axios.post(
              this.baseUrl,
              {
                from: 'Giga Ride <onboarding@resend.dev>',
                to: Array.isArray(payload.to) ? payload.to : [payload.to],
                subject: payload.subject,
                html: payload.html,
                text: payload.text || payload.subject,
              },
              {
                headers: {
                  Authorization: `Bearer ${apiKey}`,
                  'Content-Type': 'application/json',
                },
              }
            );
            return { success: true, messageId: fallbackResponse.data.id, simulated: false };
          } catch (e2: any) {
            console.warn('[Resend Onboarding Domain]', e2.response?.data || e2.message);
          }
        }
        console.error('[Resend API Error]', err.response?.data || err.message);
        return { success: true, messageId: `fallback_resend_${Date.now()}`, simulated: true };
      }
    }

    // Simulated sandbox delivery
    const simulatedId = `sim_resend_${Date.now()}`;
    console.log(`[Resend Sandbox Simulation] To: ${payload.to} | Subject: "${payload.subject}" | MessageId: ${simulatedId}`);
    return { success: true, messageId: simulatedId, simulated: true };
  }

  public async sendKycApproval(driverEmail: string, driverName: string, virtualAccount: { accountNumber: string; bankName: string; accountName: string }) {
    const html = `
      <div style="font-family: Arial, sans-serif; background: #0F172A; color: #F8FAFC; padding: 24px; border-radius: 16px;">
        <h2 style="color: #10B981;">🎉 Congratulations ${driverName}, Your Giga Ride Account is Approved!</h2>
        <p>Your documents and KYC have been verified by our compliance team. You are now live on the dispatch radar with zero commission on all rides.</p>
        
        <div style="background: #1E293B; border: 1px solid #334155; padding: 18px; border-radius: 12px; margin: 20px 0;">
          <h3 style="color: #F59E0B; margin-top: 0;">💳 Your Dedicated Korapay Virtual Bank Account</h3>
          <p style="margin: 4px 0;"><strong>Bank Name:</strong> ${virtualAccount.bankName}</p>
          <p style="margin: 4px 0;"><strong>Account Number:</strong> <span style="font-size: 18px; font-weight: bold; color: #38BDF8;">${virtualAccount.accountNumber}</span></p>
          <p style="margin: 4px 0;"><strong>Account Name:</strong> ${virtualAccount.accountName}</p>
          <p style="font-size: 12px; color: #94A3B8; margin-top: 8px;">Transfer money directly from OPay, PalmPay, Moniepoint, or your bank app to this account. Your ride credits will auto-top up instantly!</p>
        </div>
      </div>
    `;
    return this.sendEmail({ to: driverEmail, subject: 'Giga Ride Driver KYC Approved - Start Driving!', html });
  }

  public async sendAutoTopupSuccess(driverEmail: string, driverName: string, planName: string, amountNgn: number, remainingRides: number) {
    const html = `
      <div style="font-family: Arial, sans-serif; background: #0F172A; color: #F8FAFC; padding: 24px; border-radius: 16px;">
        <h2 style="color: #10B981;">⚡ Auto Top-Up Successful</h2>
        <p>Hello ${driverName}, your subscription has been automatically renewed with zero disruption to your rides.</p>
        <p><strong>Plan:</strong> ${planName} (₦${amountNgn.toLocaleString()})</p>
        <p><strong>Available Rides:</strong> <span style="color: #10B981; font-weight: bold;">${remainingRides} rides</span></p>
      </div>
    `;
    return this.sendEmail({ to: driverEmail, subject: 'Giga Ride: Auto Top-Up Successful', html });
  }

  public async sendGracePeriodWarning(driverEmail: string, driverName: string, graceRidesLeft: number) {
    const html = `
      <div style="font-family: Arial, sans-serif; background: #0F172A; color: #F8FAFC; padding: 24px; border-radius: 16px;">
        <h2 style="color: #F59E0B;">⚠️ Warning: You Are on Emergency Grace Rides</h2>
        <p>Hello ${driverName}, your ride credits are exhausted and auto top-up failed due to insufficient funds in your virtual account.</p>
        <p>You have <strong>${graceRidesLeft} emergency grace rides remaining</strong> before your account is locked out from dispatch.</p>
        <p>Please fund your dedicated virtual bank account now to prevent radar lockout.</p>
      </div>
    `;
    return this.sendEmail({ to: driverEmail, subject: 'URGENT: Emergency Grace Rides Active on Giga Ride', html });
  }

  public async sendDispatchLockoutAlert(driverEmail: string, driverName: string, virtualAccount?: { accountNumber: string; bankName: string }) {
    const html = `
      <div style="font-family: Arial, sans-serif; background: #0F172A; color: #F8FAFC; padding: 24px; border-radius: 16px;">
        <h2 style="color: #EF4444;">⛔ Dispatch Radar Locked Out</h2>
        <p>Hello ${driverName}, you have exhausted both of your emergency grace rides without topping up your subscription.</p>
        <p style="color: #FCA5A5;">Your account has been temporarily removed from dispatch and cannot receive passenger trip requests.</p>
        ${virtualAccount ? `
          <div style="background: #1E293B; border: 1px solid #EF4444; padding: 14px; border-radius: 10px; margin: 16px 0;">
            <p style="margin: 0;">Transfer funds to your virtual account to unlock instantly:</p>
            <p style="margin: 4px 0; font-size: 16px; font-weight: bold; color: #F59E0B;">${virtualAccount.bankName} - ${virtualAccount.accountNumber}</p>
          </div>
        ` : ''}
      </div>
    `;
    return this.sendEmail({ to: driverEmail, subject: 'CRITICAL: Giga Ride Driver Account Locked Out', html });
  }
}

export const resendService = new ResendService();
