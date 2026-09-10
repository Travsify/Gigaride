import axios from 'axios';
import { db } from '../../database';
import { ENV } from '../../config/env';
import { fincraService } from '../payments/fincra.service';
import { mapleradService } from '../payments/maplerad.service';
import { resendService } from '../notifications/resend.service';
import { oneSignalService } from '../notifications/onesignal.service';

export class PremblyService {
  private baseUrl = 'https://api.prembly.com/identitypass/verification';

  /**
   * Verifies National Identification Number (NIN) with Prembly Identitypass.
   */
  public async verifyNIN(driverId: string, nin: string, firstName: string, lastName: string, dob?: string) {
    const settings = await db.getPlatformSettings();
    const apiKey = settings.prembly_api_key || ENV.PREMBLY_API_KEY;
    const appId = settings.prembly_app_id || ENV.PREMBLY_APP_ID;

    let isSuccess = false;
    let confidenceScore = 95.0;
    let payload: any = {};

    if (apiKey && appId && !apiKey.includes('mock')) {
      try {
        let response;
        try {
          response = await axios.post(
            `https://api.prembly.com/verification/vnin`,
            { number_nin: nin, number: nin, firstname: firstName, surname: lastName, dob },
            { headers: { 'x-api-key': apiKey, 'app-id': appId, 'Content-Type': 'application/json' }, timeout: 8000 }
          );
        } catch (vninErr) {
          response = await axios.post(
            `${this.baseUrl}/nin`,
            { number_nin: nin, number: nin, firstname: firstName, surname: lastName, dob },
            { headers: { 'x-api-key': apiKey, 'app-id': appId, 'Content-Type': 'application/json' }, timeout: 8000 }
          );
        }
        payload = response.data;
        isSuccess = response.data?.status === true;
      } catch (err: any) {
        console.error('[Prembly NIN Verification Error]', err.response?.data || err.message);
        payload = { error: err.response?.data || err.message };
      }
    } else {
      // Sandbox Nigerian NIN simulation
      isSuccess = nin.length === 11 && !nin.startsWith('000');
      confidenceScore = isSuccess ? 96.5 : 30.0;
      payload = {
        simulated: true,
        nin,
        status: isSuccess,
        data: {
          nin,
          firstname: firstName.toUpperCase(),
          surname: lastName.toUpperCase(),
          gender: 'M',
          telephoneno: '080***',
          residence_state: 'Lagos',
        },
      };
    }

    const verificationRecord = await db.recordKycVerification({
      driver_id: driverId,
      verification_type: 'NIN',
      id_number: nin,
      status: isSuccess ? 'VERIFIED' : 'FAILED',
      confidence_score: confidenceScore,
      response_payload: payload,
    });

    if (isSuccess && settings.prembly_auto_approve) {
      await this.handleAutoApprovalIfEligible(driverId);
    }

    return {
      success: isSuccess,
      verificationId: verificationRecord.id,
      confidenceScore,
      status: isSuccess ? 'VERIFIED' : 'FAILED',
      details: payload.data || payload,
    };
  }

  /**
   * Verifies Driver's License via FRSC portal gateway on Prembly.
   */
  public async verifyDriversLicense(driverId: string, licenseNumber: string, firstName: string, lastName: string, dob?: string) {
    const settings = await db.getPlatformSettings();
    const apiKey = settings.prembly_api_key || ENV.PREMBLY_API_KEY;
    const appId = settings.prembly_app_id || ENV.PREMBLY_APP_ID;

    let isSuccess = false;
    let confidenceScore = 92.0;
    let payload: any = {};

    if (apiKey && appId && !apiKey.includes('mock')) {
      try {
        const response = await axios.post(
          `${this.baseUrl}/frsc`,
          { number: licenseNumber, frsc_number: licenseNumber, firstname: firstName, surname: lastName, dob },
          { headers: { 'x-api-key': apiKey, 'app-id': appId, 'Content-Type': 'application/json' } }
        );
        payload = response.data;
        isSuccess = response.data?.status === true;
      } catch (err: any) {
        console.error('[Prembly FRSC License Error]', err.response?.data || err.message);
        payload = { error: err.response?.data || err.message };
      }
    } else {
      // Sandbox FRSC simulation
      isSuccess = licenseNumber.length >= 8;
      confidenceScore = isSuccess ? 94.0 : 20.0;
      payload = {
        simulated: true,
        licenseNumber,
        status: isSuccess,
        data: {
          licenseNumber,
          first_name: firstName.toUpperCase(),
          last_name: lastName.toUpperCase(),
          expiry_date: new Date(Date.now() + 365 * 24 * 3600000).toISOString().split('T')[0],
          state_of_issue: 'Lagos',
        },
      };
    }

    const verificationRecord = await db.recordKycVerification({
      driver_id: driverId,
      verification_type: 'DRIVERS_LICENSE',
      id_number: licenseNumber,
      status: isSuccess ? 'VERIFIED' : 'FAILED',
      confidence_score: confidenceScore,
      response_payload: payload,
    });

    if (isSuccess && settings.prembly_auto_approve) {
      await this.handleAutoApprovalIfEligible(driverId);
    }

    return {
      success: isSuccess,
      verificationId: verificationRecord.id,
      confidenceScore,
      status: isSuccess ? 'VERIFIED' : 'FAILED',
      details: payload.data || payload,
    };
  }

  /**
   * Evaluates if driver has passed required verifications and triggers auto-approval + Korapay DVA provisioning.
   */
  private async handleAutoApprovalIfEligible(driverId: string) {
    const verifications = await db.getKycVerificationsByDriver(driverId);
    const hasNin = verifications.some((v) => v.verification_type === 'NIN' && v.status === 'VERIFIED');
    const hasLicense = verifications.some((v) => v.verification_type === 'DRIVERS_LICENSE' && v.status === 'VERIFIED');

    if (hasNin || hasLicense) {
      // Approve driver KYC
      await db.updateDriverKyc(driverId, 'APPROVED');

      // Auto-generate dedicated Fincra Virtual Bank Account
      const user = await db.findUserById(driverId);
      const driverProfile = await db.getDriverProfile(driverId);
      if (user) {
        const vba = await fincraService.generateDedicatedVirtualAccount(
          driverId,
          user.full_name,
          user.email,
          user.phone_number,
          driverProfile?.bvn || undefined
        );

        // Immediate Maplerad USDT Crypto Wallet Provisioning
        let usdtWalletAddress = '';
        const usdtNetwork = 'TRC20';
        try {
          const usdtRes = await mapleradService.generateUsdtDepositAddress(driverId, usdtNetwork, 20);
          if (usdtRes && usdtRes.depositAddress) {
            usdtWalletAddress = usdtRes.depositAddress;
            (vba as any).usdt_address = usdtWalletAddress;
            (vba as any).usdt_network = usdtNetwork;
            await db.saveStore();
          }
        } catch (mErr: any) {
          console.warn('[Prembly Auto-Approval] Maplerad USDT wallet notice:', mErr.message);
        }

        // Send congratulatory approval email with Fincra Bank + Maplerad USDT wallet details
        await resendService.sendKycApproval(user.email, user.full_name, {
          accountNumber: vba.account_number,
          bankName: vba.bank_name,
          accountName: vba.account_name,
          usdtAddress: usdtWalletAddress || undefined,
          usdtNetwork: usdtNetwork,
        });

        // Send push notification to driver device
        oneSignalService.sendPush({
          userIds: [driverId],
          heading: 'Verification Approved! 🎉',
          content: `Your profile is verified. Fincra Account: ${vba.account_number} (${vba.bank_name}) & USDT wallet are ready!`,
          data: { type: 'KYC_APPROVED', accountNumber: vba.account_number, bankName: vba.bank_name, usdtAddress: usdtWalletAddress },
        }).catch(() => {});

        // Save in-app notification in ledger
        await db.createNotification({
          user_id: driverId,
          title: 'KYC Verification Approved! 🎉',
          message: `Your identity has been verified. Dedicated Fincra Account ${vba.account_number} (${vba.bank_name}) & Maplerad USDT wallet have been generated.`,
          type: 'KYC',
          meta_data: { accountNumber: vba.account_number, bankName: vba.bank_name, usdtAddress: usdtWalletAddress },
        }).catch(() => {});

        console.log(`[Prembly Auto-Approval] Driver ${driverId} (${user.full_name}) approved: Fincra DVA ${vba.account_number}, Maplerad USDT: ${usdtWalletAddress || 'Generated'}`);
      }
    }
  }
}

export const premblyService = new PremblyService();
