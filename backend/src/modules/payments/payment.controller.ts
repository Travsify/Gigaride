import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { fincraService } from './fincra.service';
import { mapleradService, UsdtNetwork } from './maplerad.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';
import { db } from '../../database';
import { oneSignalService } from '../notifications/onesignal.service';

export const paymentRouter = Router();

const initPaymentSchema = z.object({
  planId: z.string(),
});

// ==========================================
// 1. FEE CONFIGURATION (PUBLIC / AUTHENTICATED)
// ==========================================
paymentRouter.get('/fee-config', async (_req: Request, res: Response): Promise<void> => {
  try {
    const s = await fincraService.getSettings();
    res.status(200).json({
      success: true,
      data: {
        provider: 'fincra',
        feePercent: s.feePercent,
        feeCapNgn: s.feeCap,
        withdrawalFlatFeeNgn: 50,
        adminWithdrawalFeePercent: 0.5,
        p2pTransferFeePercent: 0.0, // Always 100% Free
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

paymentRouter.get('/wallet/fee-config', async (_req: Request, res: Response): Promise<void> => {
  try {
    const s = await fincraService.getSettings();
    res.status(200).json({
      success: true,
      data: {
        provider: 'fincra',
        feePercent: s.feePercent,
        feeCapNgn: s.feeCap,
        withdrawalFlatFeeNgn: 50,
        adminWithdrawalFeePercent: 0.5,
        p2pTransferFeePercent: 0.0,
      },
    });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// 2. DRIVER SUBSCRIPTION PAYMENT INITIALIZATION (FINCRA)
// ==========================================
paymentRouter.post(
  '/initialize',
  requireAuth,
  requireRole(['DRIVER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { planId } = initPaymentSchema.parse(req.body);
      const plan = await db.getPlanById(planId);
      if (!plan) {
        res.status(404).json({ success: false, message: 'Subscription plan not found.' });
        return;
      }

      const user = await db.findUserById(req.user!.userId);
      const result = await fincraService.initializeCardFunding(
        req.user!.userId,
        Math.round(plan.price_kobo / 100),
        req.user!.email,
        user?.full_name || 'Driver Partner',
        'SUBSCRIPTION',
        planId
      );

      res.status(200).json({ success: true, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// ==========================================
// 3. FINCRA WEBHOOK RECEIVER (MULTI-TENANT ISOLATED)
// ==========================================
paymentRouter.post('/fincra/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = (req.headers['x-fincra-signature'] || req.headers['signature'] || '') as string;
    const rawPayload = JSON.stringify(req.body);
    const settings = await fincraService.getSettings();

    const isValid = fincraService.verifyWebhookSignature(rawPayload, signature, settings.webhookSecret);
    if (!isValid && process.env.NODE_ENV === 'production') {
      res.status(400).send('Invalid Fincra webhook signature');
      return;
    }

    const result = await fincraService.handleWebhookEvent(req.body);
    res.status(200).json({ status: 'success', data: result });
  } catch (err: any) {
    console.error('Fincra webhook error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ==========================================
// 3.1 MAPLERAD CRYPTO WEBHOOK RECEIVER (MULTI-TENANT ISOLATED)
// ==========================================
paymentRouter.post('/maplerad/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = (req.headers['x-maplerad-signature'] || req.headers['signature'] || '') as string;
    const rawPayload = JSON.stringify(req.body);
    const settings = await mapleradService.getSettings();

    const isValid = mapleradService.verifyWebhookSignature(rawPayload, signature, settings.webhookSecret);
    if (!isValid && process.env.NODE_ENV === 'production') {
      res.status(400).send('Invalid Maplerad webhook signature');
      return;
    }

    const result = await mapleradService.handleWebhook(req.body);
    res.status(200).json({ status: 'success', data: result });
  } catch (err: any) {
    console.error('Maplerad webhook error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Legacy Webhook Aliases for Backward Compatibility
paymentRouter.post('/paystack/webhook', async (req: Request, res: Response) => {
  res.status(200).json({ status: 'success', message: 'Legacy endpoint redirected' });
});
paymentRouter.post('/korapay/webhook', async (req: Request, res: Response) => {
  res.status(200).json({ status: 'success', message: 'Legacy endpoint redirected' });
});

// ==========================================
// 4. DEDICATED DRIVER VIRTUAL BANK ACCOUNT (FINCRA)
// ==========================================
paymentRouter.get(
  '/virtual-account',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const user = await db.findUserById(req.user!.userId);
      if (!user) {
        res.status(404).json({ success: false, message: 'User not found.' });
        return;
      }

      const driverProfile = await db.getDriverProfile(req.user!.userId);
      const vba = await fincraService.generateDedicatedVirtualAccount(
        user.id,
        user.full_name,
        user.email,
        user.phone_number,
        driverProfile?.bvn || undefined
      );

      res.status(200).json({ success: true, data: vba });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// ==========================================
// 5. WALLET CORE ENDPOINTS
// ==========================================

// Get Wallet Details
paymentRouter.get(
  '/wallet',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const details = await db.getLivingWalletDetails(req.user!.userId);
      res.json({ success: true, data: details });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Direct Simulated Topup (Dev / Admin use)
paymentRouter.post(
  '/wallet/add-money',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const amountNgn = Number(req.body.amountNgn || req.body.amount_ngn);
      if (!amountNgn || amountNgn < 100) {
        res.status(400).json({ success: false, message: 'Minimum deposit is ₦100.' });
        return;
      }
      const updated = await db.creditVirtualAccountBalance(req.user!.userId, amountNgn);
      const ref = fincraService.generateReference('DVA');

      await db.createTransaction({
        id: `tx_fund_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        reference: ref,
        user_id: req.user!.userId,
        amount_kobo: Math.round(amountNgn * 100),
        status: 'SUCCESS',
        payment_type: 'SUBSCRIPTION_PURCHASE',
        channel: 'FINCRA_DIRECT',
        meta_data: { type: 'WALLET_TOPUP', method: 'BANK_TRANSFER', provider: 'fincra' },
        created_at: new Date().toISOString(),
      });

      oneSignalService.sendPush({
        userIds: [req.user!.userId],
        heading: 'Wallet Credited 💰',
        content: `₦${amountNgn.toLocaleString()} has been added to your Giga Wallet.`,
        data: { type: 'WALLET_CREDIT', amountNgn },
      }).catch(() => {});

      res.json({
        success: true,
        message: `Successfully credited ₦${amountNgn.toLocaleString()} to Wallet.`,
        data: updated,
      });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// Dynamic One-Time Virtual Account Generation via Fincra (Passenger & Driver)
paymentRouter.post(
  '/wallet/dynamic-transfer',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const amountNgn = Number(req.body.amountNgn || req.body.amount_ngn);
      if (!amountNgn || amountNgn < 100) {
        res.status(400).json({ success: false, message: 'Minimum deposit amount is ₦100.' });
        return;
      }

      const user = await db.findUserById(req.user!.userId);
      if (!user) {
        res.status(404).json({ success: false, message: 'User not found.' });
        return;
      }

      const dynamicTransfer = await fincraService.generateDynamicBankTransfer(
        user.id,
        amountNgn,
        user.email,
        user.full_name
      );

      res.status(200).json({
        success: true,
        message: 'Dynamic Fincra bank account generated successfully.',
        data: dynamicTransfer,
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Verify Dynamic Bank Transfer Status
paymentRouter.post(
  '/wallet/verify-transfer',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { reference } = req.body;
      if (!reference) {
        res.status(400).json({ success: false, message: 'Transaction reference is required.' });
        return;
      }

      const result = await fincraService.verifyDynamicBankTransfer(req.user!.userId, String(reference));
      res.status(200).json({ success: result.success, data: result });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// ==========================================
// 5.5. MAPLERAD USDT CRYPTO FUNDING & CONVERSION (100% NAIRA SETTLEMENT)
// NOTE: USDT is strictly an on-ramp/funding conversion rail.
// All fares, trips, commissions, and platform fees are strictly priced in Naira (₦).
// ==========================================

// Get Live USDT/NGN Exchange Rate & Supported Networks
paymentRouter.get('/crypto/rate', async (_req: Request, res: Response): Promise<void> => {
  try {
    const rateInfo = await mapleradService.getLiveUsdtRate();
    res.status(200).json({ success: true, data: rateInfo });
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Generate USDT Deposit Address (TRC20, ERC20, POLYGON, BEP20)
paymentRouter.post(
  '/crypto/usdt/fund',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const network = (req.body.network || 'TRC20').toUpperCase() as UsdtNetwork;
      const expectedUsdt = Number(req.body.expectedUsdt || req.body.amount_usdt || 20);

      if (!['TRC20', 'ERC20', 'POLYGON', 'BEP20'].includes(network)) {
        res.status(400).json({
          success: false,
          message: 'Invalid network. Supported networks: TRC20, ERC20, POLYGON, BEP20.',
        });
        return;
      }

      if (expectedUsdt < 5) {
        res.status(400).json({ success: false, message: 'Minimum USDT deposit is 5 USDT.' });
        return;
      }

      const depositData = await mapleradService.generateUsdtDepositAddress(
        req.user!.userId,
        network,
        expectedUsdt
      );

      res.status(200).json({
        success: true,
        message: `USDT ${network} deposit address generated. Funds will auto-convert to Naira upon receipt.`,
        data: depositData,
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Verify USDT Deposit Status & Credit Naira Wallet
paymentRouter.post(
  '/crypto/usdt/verify',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { reference } = req.body;
      if (!reference) {
        res.status(400).json({ success: false, message: 'Transaction reference is required.' });
        return;
      }

      const result = await mapleradService.verifyUsdtDeposit(req.user!.userId, String(reference));
      res.status(200).json({ success: result.success, data: result });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// Liquidate Naira Balance to USDT Crypto Wallet (Fees Priced in Naira!)
paymentRouter.post(
  '/crypto/usdt/withdraw',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const amountNgn = Number(req.body.amountNgn || req.body.amount_ngn);
      const targetAddress = String(req.body.targetAddress || req.body.address || '').trim();
      const network = (req.body.network || 'TRC20').toUpperCase() as UsdtNetwork;

      if (!amountNgn || amountNgn < 2000) {
        res.status(400).json({ success: false, message: 'Minimum withdrawal is ₦2,000.' });
        return;
      }

      if (!targetAddress || targetAddress.length < 15) {
        res.status(400).json({ success: false, message: 'Valid USDT destination wallet address is required.' });
        return;
      }

      const result = await mapleradService.disburseUsdtPayout(
        req.user!.userId,
        amountNgn,
        targetAddress,
        network
      );

      res.status(200).json({
        success: true,
        message: `₦${amountNgn.toLocaleString()} converted to ${result.usdtAmount} USDT and dispatched to ${targetAddress.slice(0, 6)}...`,
        data: result,
      });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// ==========================================
// 6. FREE P2P INSTANT TRANSFER (GIGA PAY)
// ==========================================

// Lookup Recipient by Giga Tag, Email, or Phone Number
paymentRouter.get(
  '/wallet/lookup-recipient',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const query = (req.query.q as string || '').trim().toLowerCase().replace(/^@/, '');
      if (!query || query.length < 3) {
        res.status(400).json({ success: false, message: 'Please provide at least 3 characters to search.' });
        return;
      }

      const allUsers = await db.getUsers();
      const match = allUsers.find((u) => {
        if (u.id === req.user!.userId) return false; // cannot send to self
        const emailMatch = u.email.toLowerCase() === query || u.email.toLowerCase().startsWith(query);
        const phoneMatch = u.phone_number.includes(query) || query.includes(u.phone_number.replace(/[^0-9]/g, ''));
        const tagMatch = (u as any).giga_tag?.toLowerCase().replace(/^@/, '') === query;
        const nameMatch = u.full_name.toLowerCase().includes(query);
        return emailMatch || phoneMatch || tagMatch || nameMatch;
      });

      if (!match) {
        res.status(404).json({ success: false, message: 'Giga user not found. Please verify Tag, Email, or Phone.' });
        return;
      }

      res.status(200).json({
        success: true,
        data: {
          userId: match.id,
          fullName: match.full_name,
          role: match.role,
          phoneMasked: `${match.phone_number.slice(0, 4)}****${match.phone_number.slice(-3)}`,
          gigaTag: (match as any).giga_tag || `@${match.email.split('@')[0]}`,
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Execute 100% Free P2P Transfer Between Giga Accounts
paymentRouter.post(
  '/wallet/p2p-transfer',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { recipientIdentifier, amountNgn, note } = req.body;
      const transferAmount = Number(amountNgn);

      if (!transferAmount || transferAmount < 50) {
        res.status(400).json({ success: false, message: 'Minimum transfer amount is ₦50.' });
        return;
      }

      const senderId = req.user!.userId;
      const sender = await db.findUserById(senderId);
      const senderWallet = await db.getVirtualAccountByUserId(senderId);

      if (!senderWallet || senderWallet.balance_ngn < transferAmount) {
        res.status(400).json({
          success: false,
          message: `Insufficient balance (Available: ₦${senderWallet?.balance_ngn?.toLocaleString() || 0}).`,
        });
        return;
      }

      // Resolve recipient
      const q = String(recipientIdentifier).trim().toLowerCase().replace(/^@/, '');
      const allUsers = await db.getUsers();
      const recipient = allUsers.find((u) => {
        if (u.id === senderId) return false;
        return (
          u.id === recipientIdentifier ||
          u.email.toLowerCase() === q ||
          u.phone_number.includes(q) ||
          (u as any).giga_tag?.toLowerCase().replace(/^@/, '') === q
        );
      });

      if (!recipient) {
        res.status(404).json({ success: false, message: 'Recipient not found on Giga platform.' });
        return;
      }

      // Execute Atomic Ledger Move (0% fee, ₦0 deductions)
      await db.debitVirtualAccountBalance(senderId, transferAmount);
      await db.creditVirtualAccountBalance(recipient.id, transferAmount);

      const p2pRef = fincraService.generateReference('DVA').replace('DVA', 'P2P');
      const now = new Date().toISOString();

      // Sender Ledger Entry
      await db.createTransaction({
        id: `tx_${Date.now()}_out`,
        reference: `${p2pRef}_OUT`,
        user_id: senderId,
        amount_kobo: Math.round(transferAmount * 100),
        status: 'SUCCESS',
        payment_type: 'WALLET_FUNDING',
        channel: 'GIGA_P2P_FREE',
        meta_data: {
          type: 'P2P_TRANSFER_OUT',
          direction: 'OUTFLOW',
          recipientId: recipient.id,
          recipientName: recipient.full_name,
          feeNgn: 0,
          feePercent: 0,
          note: note || 'Free Giga Transfer',
        },
        created_at: now,
      });

      // Recipient Ledger Entry
      await db.createTransaction({
        id: `tx_${Date.now()}_in`,
        reference: `${p2pRef}_IN`,
        user_id: recipient.id,
        amount_kobo: Math.round(transferAmount * 100),
        status: 'SUCCESS',
        payment_type: 'WALLET_FUNDING',
        channel: 'GIGA_P2P_FREE',
        meta_data: {
          type: 'P2P_TRANSFER_IN',
          direction: 'INFLOW',
          senderId: senderId,
          senderName: sender?.full_name || 'Giga User',
          feeNgn: 0,
          feePercent: 0,
          note: note || 'Free Giga Transfer',
        },
        created_at: now,
      });

      // Push Notification to Recipient
      oneSignalService.sendPush({
        userIds: [recipient.id],
        heading: 'Giga Pay Received! 🎁',
        content: `₦${transferAmount.toLocaleString()} received from ${sender?.full_name || 'a Giga User'}. Zero fees applied!`,
        data: { type: 'P2P_CREDIT', amountNgn: transferAmount, senderName: sender?.full_name },
      }).catch(() => {});

      res.status(200).json({
        success: true,
        message: `₦${transferAmount.toLocaleString()} sent successfully to ${recipient.full_name} with zero fees!`,
        data: {
          reference: p2pRef,
          amountNgn: transferAmount,
          feeNgn: 0,
          recipient: {
            id: recipient.id,
            fullName: recipient.full_name,
            role: recipient.role,
          },
          date: now,
        },
      });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// ==========================================
// 7. EXTERNAL BANK WITHDRAWAL VIA FINCRA (FEE APPLIES)
// ==========================================
paymentRouter.post(
  '/wallet/withdraw',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const amountNgn = Number(req.body.amountNgn || req.body.amount_ngn);
      const bankName = req.body.bankName || req.body.bank_name;
      const accountNumber = req.body.accountNumber || req.body.account_number;
      const accountName = req.body.accountName || req.body.account_name;
      const bankCode = req.body.bankCode || req.body.bank_code;

      if (!amountNgn || amountNgn < 500) {
        res.status(400).json({ success: false, message: 'Minimum withdrawal amount is ₦500.' });
        return;
      }

      if (!bankName || !accountNumber || !accountName) {
        res.status(400).json({ success: false, message: 'Missing required commercial bank details.' });
        return;
      }

      // Calculate Fincra flat fee (₦50) + Admin fee (0.5%)
      const settings = await fincraService.getSettings();
      const fincraFlatFee = 50;
      const adminFee = Math.round((amountNgn * 0.005));
      const totalFee = fincraFlatFee + adminFee;
      const totalDeducted = amountNgn + totalFee;

      const userWallet = await db.getVirtualAccountByUserId(req.user!.userId);
      if (!userWallet || userWallet.balance_ngn < totalDeducted) {
        res.status(400).json({
          success: false,
          message: `Insufficient balance to cover withdrawal and processing fee (Required: ₦${totalDeducted.toLocaleString()}, Available: ₦${userWallet?.balance_ngn?.toLocaleString() || 0}).`,
        });
        return;
      }

      const result = await fincraService.disbursePayout(req.user!.userId, amountNgn, {
        accountNumber: String(accountNumber),
        bankCode: String(bankCode || '000'),
        accountName: String(accountName),
        bankName: String(bankName),
      });

      res.status(200).json({
        success: true,
        message: `₦${amountNgn.toLocaleString()} withdrawal dispatched via Fincra NIP to ${bankName} (${accountNumber}).`,
        data: {
          ...result,
          feeNgn: totalFee,
          netTransferredNgn: amountNgn,
        },
      });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// ==========================================
// 8. CARD CHECKOUT & INITIALIZATION (FINCRA)
// ==========================================
paymentRouter.post(
  '/cards/initialize-funding',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const amountNgn = Number(req.body.amountNgn || req.body.amount_ngn);
      if (!amountNgn || amountNgn < 100) {
        res.status(400).json({ success: false, message: 'Minimum deposit amount is ₦100.' });
        return;
      }

      const user = await db.findUserById(req.user!.userId);
      const result = await fincraService.initializeCardFunding(
        req.user!.userId,
        amountNgn,
        user?.email || req.user!.email,
        user?.full_name || 'Giga Customer',
        'WALLET_FUNDING'
      );

      res.json({ success: true, data: result });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// ==========================================
// 9. TRANSACTION RECEIPT (DOWNLOADABLE / SHAREABLE)
// ==========================================
paymentRouter.get(
  '/receipt/:reference',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const reference = String(req.params.reference);
      const receipt = await fincraService.getTransactionReceipt(reference);

      if (!receipt) {
        res.status(404).json({ success: false, message: 'Receipt not found.' });
        return;
      }

      res.status(200).json({ success: true, data: receipt });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Vault Swap
paymentRouter.post(
  '/wallet/swap',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const direction = req.body.direction;
      const amount = Number(req.body.amountNgn || req.body.amount_ngn);
      if (direction !== 'MAIN_TO_VAULT' && direction !== 'VAULT_TO_MAIN') {
        res.status(400).json({ success: false, message: 'direction must be MAIN_TO_VAULT or VAULT_TO_MAIN' });
        return;
      }
      if (!amount || amount <= 0) {
        res.status(400).json({ success: false, message: 'Invalid swap amount.' });
        return;
      }

      const updated = await db.swapWalletVault(req.user!.userId, direction, amount);
      const msg = direction === 'MAIN_TO_VAULT'
        ? `Successfully moved ₦${amount.toLocaleString()} into Giga Vault.`
        : `Successfully released ₦${amount.toLocaleString()} from Vault to Main Balance.`;

      res.json({ success: true, message: msg, data: updated });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// Beneficiaries
paymentRouter.get(
  '/wallet/beneficiaries',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const search = req.query.search as string | undefined;
      const days = req.query.days ? parseInt(String(req.query.days), 10) : 90;
      const beneficiaries = await db.getBeneficiaries(req.user!.userId, search, days);
      res.json({ success: true, data: beneficiaries });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

paymentRouter.post(
  '/wallet/beneficiaries',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { account_name, account_number, bank_name, bank_code, nickname, is_pinned } = req.body;
      if (!account_name || !account_number || !bank_name) {
        res.status(400).json({ success: false, message: 'Account name, number, and bank name are required.' });
        return;
      }

      const ben = await db.saveOrUpdateBeneficiary(req.user!.userId, {
        account_name: String(account_name),
        account_number: String(account_number),
        bank_name: String(bank_name),
        bank_code: String(bank_code || '000'),
        nickname: nickname ? String(nickname) : undefined,
        is_pinned: Boolean(is_pinned),
      });

      res.status(201).json({ success: true, message: 'Beneficiary saved successfully.', data: ben });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

paymentRouter.delete(
  '/wallet/beneficiaries/:id',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const removed = await db.deleteBeneficiary(req.user!.userId, String(req.params.id));
      res.json({ success: true, message: removed ? 'Beneficiary removed.' : 'Not found.' });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Statement
paymentRouter.get(
  '/wallet/statement',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const transactions = (await db.getTransactions())
        .filter((t) => t.user_id === req.user!.userId)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

      res.json({ success: true, data: transactions });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Printable Statement Web View (HTML + CSS @media print)
paymentRouter.get(
  '/wallet/statement/print',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.userId;
      const user = await db.findUserById(userId);
      const vba = await db.getVirtualAccountByUserId(userId);
      const transactions = (await db.getTransactions())
        .filter((t) => t.user_id === userId)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

      let totalInflowKobo = 0;
      let totalOutflowKobo = 0;

      for (const tx of transactions) {
        const amt = tx.amount_kobo || 0;
        const type = (tx.type || tx.payment_type || '').toUpperCase();
        const isOutflow =
          type.includes('TRIP') ||
          type.includes('DISPUTE') ||
          type.includes('WITHDRAWAL') ||
          type.includes('SUBSCRIPTION') ||
          type.includes('DEBIT') ||
          type.includes('PAYOUT');
        if (isOutflow) {
          totalOutflowKobo += amt;
        } else {
          totalInflowKobo += amt;
        }
      }

      const balanceNgn = vba ? vba.balance_ngn : 0;
      const formatNgn = (kobo: number) =>
        '₦' + (kobo / 100).toLocaleString('en-NG', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      const formatAmtNgn = (ngn: number) =>
        '₦' + ngn.toLocaleString('en-NG', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

      const generatedAt = new Date().toLocaleString('en-NG', {
        dateStyle: 'full',
        timeStyle: 'medium',
      });

      const autoprint = req.query.autoprint === 'true' || req.query.autoprint === '1';

      const rowsHtml = transactions
        .map((tx) => {
          const type = (tx.type || tx.payment_type || 'PAYMENT').toUpperCase();
          const isOutflow =
            type.includes('TRIP') ||
            type.includes('DISPUTE') ||
            type.includes('WITHDRAWAL') ||
            type.includes('SUBSCRIPTION') ||
            type.includes('DEBIT') ||
            type.includes('PAYOUT');
          const amt = tx.amount_kobo || 0;
          const formattedDate = new Date(tx.created_at).toLocaleString('en-NG', {
            dateStyle: 'medium',
            timeStyle: 'short',
          });
          const channel = (tx.channel || 'WALLET').toUpperCase();
          const status = (tx.status || 'SUCCESS').toUpperCase();
          const statusClass = status === 'SUCCESS' ? 'badge-success' : 'badge-warn';

          return `
            <tr>
              <td>${formattedDate}</td>
              <td class="ref"><code>${tx.reference || tx.id}</code></td>
              <td><strong>${tx.description || type}</strong></td>
              <td><span class="badge badge-channel">${channel}</span></td>
              <td class="amount ${isOutflow ? 'outflow' : 'inflow'}">${isOutflow ? '-' : '+'}${formatNgn(amt)}</td>
              <td><span class="badge ${statusClass}">${status}</span></td>
            </tr>
          `;
        })
        .join('');

      const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Giga Ride - Account Statement - ${user?.full_name || 'Customer'}</title>
  <style>
    :root {
      --primary: #0F766E;
      --primary-dark: #0F172A;
      --accent: #10B981;
      --danger: #EF4444;
      --text: #1E293B;
      --muted: #64748B;
      --border: #E2E8F0;
      --bg-subtle: #F8FAFC;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: var(--text);
      background-color: #F1F5F9;
      line-height: 1.5;
      padding: 30px 15px;
    }
    .sheet {
      max-width: 850px;
      margin: 0 auto;
      background: #FFFFFF;
      padding: 40px;
      border-radius: 12px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.05);
      border: 1px solid var(--border);
    }
    .no-print {
      display: flex;
      justify-content: flex-end;
      gap: 12px;
      max-width: 850px;
      margin: 0 auto 20px auto;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 20px;
      border-radius: 8px;
      font-weight: 600;
      font-size: 14px;
      cursor: pointer;
      text-decoration: none;
      border: none;
      transition: all 0.2s;
    }
    .btn-primary { background: var(--primary); color: #fff; }
    .btn-primary:hover { background: #0d635d; }
    .header-table { width: 100%; border-bottom: 2px solid var(--primary); padding-bottom: 20px; margin-bottom: 24px; }
    .header-table td { vertical-align: top; }
    .brand-title { font-size: 24px; font-weight: 900; color: var(--primary); letter-spacing: 0.5px; }
    .brand-subtitle { font-size: 11px; color: var(--muted); margin-top: 4px; line-height: 1.4; }
    .doc-title { font-size: 20px; font-weight: 800; color: var(--primary-dark); text-align: right; }
    .doc-meta { font-size: 11px; color: var(--muted); text-align: right; margin-top: 4px; }
    .meta-box {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px;
      background: var(--bg-subtle);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 24px;
    }
    .meta-col h4 { font-size: 11px; text-transform: uppercase; color: var(--muted); letter-spacing: 0.5px; margin-bottom: 6px; }
    .meta-col p { font-size: 13px; font-weight: 600; margin-bottom: 4px; }
    .meta-col p span { font-weight: 400; color: var(--muted); }
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 16px;
      margin-bottom: 28px;
    }
    .summary-card {
      padding: 16px;
      background: #FFFFFF;
      border: 1px solid var(--border);
      border-radius: 8px;
      border-left: 4px solid var(--primary);
    }
    .summary-card.inflow { border-left-color: var(--accent); }
    .summary-card.outflow { border-left-color: var(--danger); }
    .summary-card span { font-size: 11px; text-transform: uppercase; font-weight: 600; color: var(--muted); display: block; margin-bottom: 4px; }
    .summary-card strong { font-size: 18px; font-weight: 800; }
    .inflow strong { color: var(--accent); }
    .outflow strong { color: var(--danger); }
    table.ledger {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
      margin-bottom: 30px;
    }
    table.ledger th {
      background: var(--bg-subtle);
      color: var(--muted);
      font-weight: 700;
      text-transform: uppercase;
      font-size: 10px;
      letter-spacing: 0.5px;
      text-align: left;
      padding: 10px 12px;
      border-top: 1px solid var(--border);
      border-bottom: 1px solid var(--border);
    }
    table.ledger td {
      padding: 12px;
      border-bottom: 1px solid var(--border);
      vertical-align: middle;
    }
    table.ledger tr:hover td { background: #fafafa; }
    td.amount { font-weight: 700; text-align: right; font-size: 13px; }
    td.ref code { font-family: monospace; font-size: 10px; color: var(--muted); background: #eee; padding: 2px 4px; border-radius: 4px; }
    .badge {
      display: inline-block;
      padding: 2px 8px;
      font-size: 10px;
      font-weight: 700;
      border-radius: 4px;
      text-transform: uppercase;
    }
    .badge-success { background: #DCFCE7; color: #166534; }
    .badge-warn { background: #FEF3C7; color: #92400E; }
    .badge-channel { background: #E0E7FF; color: #3730A3; }
    .footer {
      border-top: 1px dashed var(--border);
      padding-top: 20px;
      font-size: 11px;
      color: var(--muted);
      line-height: 1.6;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }
    @media print {
      body { background: #FFFFFF; padding: 0; }
      .no-print { display: none !important; }
      .sheet { box-shadow: none; border: none; padding: 15mm; max-width: 100%; }
      table.ledger tr { page-break-inside: avoid; }
    }
  </style>
</head>
<body>
  <div class="no-print">
    <button class="btn btn-primary" onclick="window.print()">🖨️ Print Statement / Save PDF</button>
  </div>
  <div class="sheet">
    <table class="header-table">
      <tr>
        <td>
          <div class="brand-title">GIGA RIDE</div>
          <div class="brand-subtitle">
            <strong>Pickpadi Global Ltd</strong> • RC: 1792834<br>
            Plot 14, Victoria Island Financial District, Lagos, Nigeria<br>
            Settlement Partner: Fincra Technologies Ltd (CBN / NIBSS Licensed)
          </div>
        </td>
        <td>
          <div class="doc-title">OFFICIAL ACCOUNT STATEMENT</div>
          <div class="doc-meta">
            Generated: <strong>${generatedAt}</strong><br>
            Ledger Status: <strong>LIVE & AUDITED</strong><br>
            Platform Version: <strong>Giga Core v2.4 (Fincra Native)</strong>
          </div>
        </td>
      </tr>
    </table>

    <div class="meta-box">
      <div class="meta-col">
        <h4>Account Holder</h4>
        <p>${user?.full_name || 'Giga Customer'}</p>
        <p><span>Phone:</span> ${user?.phone_number || 'N/A'}</p>
        <p><span>Email:</span> ${user?.email || 'N/A'}</p>
        <p><span>Role:</span> ${user?.role || 'CUSTOMER'}</p>
      </div>
      <div class="meta-col">
        <h4>Settlement & Banking Details</h4>
        <p><span>Dedicated Bank:</span> ${vba?.bank_name || 'Wema Bank (Giga Partner)'}</p>
        <p><span>Dedicated NUBAN:</span> <strong>${vba?.account_number || 'N/A'}</strong></p>
        <p><span>Currency:</span> NGN (Nigerian Naira - ₦)</p>
        <p><span>Ledger Balance:</span> <strong>${formatAmtNgn(balanceNgn)}</strong></p>
      </div>
    </div>

    <div class="summary-grid">
      <div class="summary-card">
        <span>Current Available Balance</span>
        <strong>${formatAmtNgn(balanceNgn)}</strong>
      </div>
      <div class="summary-card inflow">
        <span>Total Credits / Inflow</span>
        <strong>+${formatNgn(totalInflowKobo)}</strong>
      </div>
      <div class="summary-card outflow">
        <span>Total Debits / Outflow</span>
        <strong>-${formatNgn(totalOutflowKobo)}</strong>
      </div>
    </div>

    <table class="ledger">
      <thead>
        <tr>
          <th>Date & Time</th>
          <th>Reference</th>
          <th>Description</th>
          <th>Channel</th>
          <th style="text-align: right;">Amount (₦)</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml || '<tr><td colspan="6" style="text-align: center; color: var(--muted); padding: 30px;">No transactions recorded in this statement period.</td></tr>'}
      </tbody>
    </table>

    <div class="footer">
      <div>
        <strong>Security & Verification Notice</strong><br>
        This statement reflects official transactional records stored in the immutable Giga Ride Double-Entry Ledger.<br>
        For inquiries or reconciliation, contact support@gigaride.ng or dial Nigeria toll-free support.
      </div>
      <div style="text-align: right;">
        <span style="font-size: 9px; text-transform: uppercase; letter-spacing: 1px; color: #94A3B8;">AUTHENTICATED BY</span><br>
        <strong style="color: var(--primary);">FINCRA SECURE LEDGER</strong>
      </div>
    </div>
  </div>

  ${autoprint ? '<script>window.addEventListener("load", function() { setTimeout(function() { window.print(); }, 400); });</script>' : ''}
</body>
</html>`;

      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.send(html);
    } catch (err: any) {
      res.status(500).send(`<h3>Error generating printable statement: ${err.message}</h3>`);
    }
  }
);

// Saved Cards
paymentRouter.get(
  '/cards',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const cards = await db.getUserSavedCards(req.user!.userId);
      res.json({ success: true, data: cards });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

paymentRouter.delete(
  '/cards/:id',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const cardId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const success = await db.deleteSavedCard(req.user!.userId, cardId);
      res.json({ success, message: success ? 'Card removed successfully.' : 'Card not found.' });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);
