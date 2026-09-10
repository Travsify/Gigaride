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

    const simulatedId = `sim_resend_${Date.now()}`;
    console.log(`[Resend Sandbox Simulation] To: ${payload.to} | Subject: "${payload.subject}" | MessageId: ${simulatedId}`);
    return { success: true, messageId: simulatedId, simulated: true };
  }

  /**
   * Premium branded HTML template wrapper
   */
  public getTemplateWrapper(title: string, contentHtml: string): string {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0B0F19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #0B0F19; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 540px; background-color: #111827; border-radius: 16px; border: 1px solid #1F2937; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="padding: 24px 32px; background: linear-gradient(135deg, #064E3B 0%, #111827 100%); border-bottom: 1px solid #1F2937;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <div style="display: inline-block; background-color: #10B981; color: #064E3B; font-weight: 900; font-size: 13px; padding: 5px 12px; border-radius: 6px; letter-spacing: 1.5px; margin-bottom: 6px;">
                      🚖 GIGA RIDE
                    </div>
                    <div style="color: #9CA3AF; font-size: 11px; letter-spacing: 1.2px; text-transform: uppercase;">
                      Intelligent Urban Mobility & Logistics
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding: 32px; color: #F3F4F6;">
              ${contentHtml}
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding: 22px 32px 28px 32px; background-color: #0B0F19; border-top: 1px solid #1F2937; text-align: center;">
              <p style="margin: 0 0 6px 0; font-size: 12px; color: #9CA3AF;">
                Zero-Commission Bidding Platform • Nigeria (Lagos • Abuja • Port Harcourt)
              </p>
              <p style="margin: 0; font-size: 11px; color: #6B7280;">
                Support: <a href="mailto:info@getgigaride.com" style="color: #10B981; text-decoration: none;">info@getgigaride.com</a> • <a href="https://engine.getgigaride.com" style="color: #10B981; text-decoration: none;">getgigaride.com</a>
              </p>
              <p style="margin: 12px 0 0 0; font-size: 10px; color: #4B5563;">
                © 2026 Giga Ride Technologies Inc. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;
  }

  public async sendOtpEmail(email: string, otp: string, purpose: string = 'verification') {
    const content = `
      <h2 style="color: #10B981; margin-top: 0; font-size: 22px;">Security Verification Code</h2>
      <p style="color: #D1D5DB; font-size: 14px; line-height: 1.5;">
        You requested a security verification code for your Giga Ride account (${purpose}). Please enter this code in the app to continue:
      </p>
      
      <div style="background-color: #1F2937; border: 1px solid #374151; border-radius: 12px; text-align: center; padding: 22px; margin: 24px 0;">
        <span style="font-size: 36px; font-weight: 900; letter-spacing: 10px; color: #10B981; font-family: monospace;">${otp}</span>
      </div>

      <p style="color: #9CA3AF; font-size: 12px; line-height: 1.4; margin-bottom: 0;">
        ⏱️ <strong>This code will expire in 15 minutes.</strong><br>
        If you did not make this request, your account is secure — simply ignore this message.
      </p>
    `;
    return this.sendEmail({
      to: email,
      subject: `Your Giga Ride Verification Code: ${otp}`,
      html: this.getTemplateWrapper('Security Verification Code', content),
    });
  }

  public async sendWelcomePassengerEmail(email: string, fullName: string) {
    const content = `
      <h2 style="color: #10B981; margin-top: 0;">Welcome to Giga Ride, ${fullName}! 🎉</h2>
      <p style="color: #D1D5DB; font-size: 14px; line-height: 1.6;">
        Your passenger account is now active. With Giga Ride, you get transparent, fair ride pricing where drivers keep 100% of their earnings with zero commission.
      </p>
      <div style="background-color: #1F2937; border-left: 4px solid #10B981; padding: 14px 18px; border-radius: 8px; margin: 20px 0;">
        <p style="margin: 0; color: #F3F4F6; font-weight: bold; font-size: 14px;">What makes Giga Ride different?</p>
        <p style="margin: 6px 0 0 0; color: #9CA3AF; font-size: 13px;">• Direct driver-to-passenger bidding<br>• Instant driver arrival tracking<br>• Built-in Naira Wallet for fast cashless payments</p>
      </div>
      <p style="color: #D1D5DB; font-size: 14px;">Open your Giga Ride app to request your first ride today!</p>
    `;
    return this.sendEmail({
      to: email,
      subject: 'Welcome to Giga Ride - Your Account is Ready! 🚗',
      html: this.getTemplateWrapper('Welcome to Giga Ride', content),
    });
  }

  public async sendDriverRegistrationSuccessEmail(email: string, fullName: string, vehicleInfo: { make: string; model: string; plate: string }) {
    const content = `
      <h2 style="color: #10B981; margin-top: 0;">Welcome to the Driver Cockpit, ${fullName}! 🚖</h2>
      <p style="color: #D1D5DB; font-size: 14px; line-height: 1.6;">
        Congratulations! Your driver account has been successfully registered. You are now part of Nigeria's first zero-commission driver network.
      </p>
      <div style="background-color: #1F2937; border: 1px solid #374151; padding: 18px; border-radius: 12px; margin: 20px 0;">
        <h3 style="color: #F59E0B; margin: 0 0 10px 0; font-size: 15px;">🚗 Registered Vehicle Details</h3>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>Vehicle:</strong> ${vehicleInfo.make} ${vehicleInfo.model}</p>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>License Plate:</strong> <span style="color: #10B981; font-weight: bold;">${vehicleInfo.plate}</span></p>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>Welcome Bonus:</strong> <span style="color: #F59E0B; font-weight: bold;">5 Free Promotional Welcome Rides Active!</span></p>
      </div>
      <p style="color: #9CA3AF; font-size: 13px;">
        To accept passenger trip requests on the live radar, submit your Driver's License and NIN in the KYC screen.
      </p>
    `;
    return this.sendEmail({
      to: email,
      subject: 'Welcome to Giga Driver - 5 Free Welcome Rides Activated!',
      html: this.getTemplateWrapper('Driver Account Activated', content),
    });
  }

  public async sendKycApproval(driverEmail: string, driverName: string, virtualAccount: { accountNumber: string; bankName: string; accountName: string; usdtAddress?: string; usdtNetwork?: string }) {
    const content = `
      <h2 style="color: #10B981; margin-top: 0;">🎉 Congratulations ${driverName}, Your Account is Approved!</h2>
      <p style="color: #D1D5DB; font-size: 14px; line-height: 1.6;">Your documents and KYC/KYB have been successfully verified. You are now live on the dispatch radar with zero commission on all rides.</p>
      
      <div style="background: #1F2937; border: 1px solid #374151; padding: 18px; border-radius: 12px; margin: 20px 0;">
        <h3 style="color: #F59E0B; margin-top: 0; font-size: 15px;">💳 Your Dedicated Fincra NUBAN Bank Account</h3>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>Bank Name:</strong> ${virtualAccount.bankName}</p>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>Account Number:</strong> <span style="font-size: 18px; font-weight: bold; color: #38BDF8;">${virtualAccount.accountNumber}</span></p>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>Account Name:</strong> ${virtualAccount.accountName}</p>
        <p style="font-size: 12px; color: #9CA3AF; margin-top: 10px;">Direct transfers from OPay, PalmPay, Moniepoint, or any banking app are credited instantly.</p>
      </div>

      ${virtualAccount.usdtAddress ? `
      <div style="background: #0F172A; border: 1px solid #0D9488; padding: 18px; border-radius: 12px; margin: 20px 0;">
        <h3 style="color: #2DD4BF; margin-top: 0; font-size: 15px;">💎 Your Dedicated Maplerad USDT Crypto Wallet</h3>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>Network:</strong> ${virtualAccount.usdtNetwork || 'TRC20'}</p>
        <p style="margin: 4px 0; color: #D1D5DB; font-size: 13px;"><strong>Deposit Address:</strong> <span style="font-family: monospace; font-size: 14px; font-weight: bold; color: #2DD4BF;">${virtualAccount.usdtAddress}</span></p>
        <p style="font-size: 12px; color: #9CA3AF; margin-top: 10px;">USDT deposits are automatically converted to Naira (₦) at live institutional rates with zero commission.</p>
      </div>
      ` : ''}
    `;
    return this.sendEmail({
      to: driverEmail,
      subject: 'Giga Ride Driver KYC Approved - Start Driving!',
      html: this.getTemplateWrapper('KYC Approved', content),
    });
  }

  public async sendAutoTopupSuccess(driverEmail: string, driverName: string, planName: string, amountNgn: number, remainingRides: number) {
    const content = `
      <h2 style="color: #10B981; margin-top: 0;">⚡ Auto Top-Up Successful</h2>
      <p style="color: #D1D5DB; font-size: 14px;">Hello ${driverName}, your subscription has been automatically renewed with zero disruption to your rides.</p>
      <div style="background-color: #1F2937; padding: 14px 18px; border-radius: 8px; margin: 16px 0;">
        <p style="margin: 4px 0; color: #D1D5DB;"><strong>Plan:</strong> ${planName} (₦${amountNgn.toLocaleString()})</p>
        <p style="margin: 4px 0; color: #D1D5DB;"><strong>Available Rides:</strong> <span style="color: #10B981; font-weight: bold;">${remainingRides} rides</span></p>
      </div>
    `;
    return this.sendEmail({
      to: driverEmail,
      subject: 'Giga Ride: Auto Top-Up Successful',
      html: this.getTemplateWrapper('Auto Top-Up Successful', content),
    });
  }

  public async sendGracePeriodWarning(driverEmail: string, driverName: string, graceRidesLeft: number) {
    const content = `
      <h2 style="color: #F59E0B; margin-top: 0;">⚠️ Emergency Grace Rides Active</h2>
      <p style="color: #D1D5DB; font-size: 14px;">Hello ${driverName}, your ride credits are exhausted and auto top-up failed due to insufficient funds in your virtual account.</p>
      <div style="background: #1F2937; border-left: 4px solid #F59E0B; padding: 14px 18px; border-radius: 8px; margin: 16px 0;">
        <p style="margin: 0; color: #F59E0B; font-weight: bold;">${graceRidesLeft} emergency grace rides remaining</p>
        <p style="margin: 6px 0 0 0; color: #9CA3AF; font-size: 12px;">Please fund your dedicated virtual bank account now to prevent radar lockout.</p>
      </div>
    `;
    return this.sendEmail({
      to: driverEmail,
      subject: 'URGENT: Emergency Grace Rides Active on Giga Ride',
      html: this.getTemplateWrapper('Emergency Grace Rides Active', content),
    });
  }

  public async sendDispatchLockoutAlert(driverEmail: string, driverName: string, virtualAccount?: { accountNumber: string; bankName: string }) {
    const content = `
      <h2 style="color: #EF4444; margin-top: 0;">⛔ Dispatch Radar Locked Out</h2>
      <p style="color: #D1D5DB; font-size: 14px;">Hello ${driverName}, you have exhausted your emergency grace rides without topping up your subscription.</p>
      <p style="color: #FCA5A5; font-size: 13px;">Your account has been temporarily removed from dispatch and cannot receive passenger trip requests.</p>
      ${virtualAccount ? `
        <div style="background: #1F2937; border: 1px solid #EF4444; padding: 14px; border-radius: 10px; margin: 16px 0;">
          <p style="margin: 0; color: #9CA3AF; font-size: 12px;">Transfer funds to your virtual account to unlock instantly:</p>
          <p style="margin: 6px 0 0 0; font-size: 16px; font-weight: bold; color: #F59E0B;">${virtualAccount.bankName} • ${virtualAccount.accountNumber}</p>
        </div>
      ` : ''}
    `;
    return this.sendEmail({
      to: driverEmail,
      subject: 'CRITICAL: Giga Ride Driver Account Locked Out',
      html: this.getTemplateWrapper('Dispatch Locked Out', content),
    });
  }
}

export const resendService = new ResendService();

