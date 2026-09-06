import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { paystackService } from './paystack.service';
import { korapayService } from './korapay.service';
import { AuthenticatedRequest, requireAuth, requireRole } from '../auth/auth.middleware';
import { db } from '../../database';
import { oneSignalService } from '../notifications/onesignal.service';

export const paymentRouter = Router();

const initPaymentSchema = z.object({
  planId: z.string(),
});

// Driver initializes Paystack card payment checkout
paymentRouter.post(
  '/initialize',
  requireAuth,
  requireRole(['DRIVER']),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { planId } = initPaymentSchema.parse(req.body);
      const result = await paystackService.initializeSubscriptionPayment(
        req.user!.userId,
        planId,
        req.user!.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (error: any) {
      res.status(400).json({ success: false, message: error.message });
    }
  }
);

// Paystack Webhook Handler
paymentRouter.post('/paystack/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = req.headers['x-paystack-signature'] as string;
    const rawPayload = JSON.stringify(req.body);

    const isValid = await paystackService.verifyWebhookSignature(rawPayload, signature || '');
    if (!isValid) {
      res.status(400).send('Invalid signature');
      return;
    }

    const event = req.body;
    if (event.event === 'charge.success') {
      await paystackService.handleSuccessfulCharge(event.data);
    }

    res.status(200).json({ status: 'success' });
  } catch (err: any) {
    console.error('Paystack webhook error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Dedicated Korapay Virtual Account (Fetch or Provision)
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

      // Dedicated NUBAN Virtual Account generated strictly via Korapay API
      const vba = await korapayService.generateDedicatedVirtualAccount(
        user.id,
        user.full_name,
        user.email,
        user.phone_number
      );

      res.status(200).json({ success: true, data: vba });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// Korapay Webhook Handler (Incoming NIP Bank Transfers)
paymentRouter.post('/korapay/webhook', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = (req.headers['x-korapay-signature'] || '') as string;
    const rawPayload = JSON.stringify(req.body);

    const isValid = korapayService.verifyWebhookSignature(rawPayload, signature);
    if (!isValid) {
      res.status(400).send('Invalid Korapay signature');
      return;
    }

    await korapayService.handleVirtualAccountCreditWebhook(req.body);
    res.status(200).json({ status: 'success' });
  } catch (err: any) {
    console.error('Korapay webhook error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Development / Testing Utility: Simulate Instant NIP Bank Transfer
paymentRouter.post(
  '/korapay/simulate-bank-transfer',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { amountNgn } = req.body;
      const transferAmount = Number(amountNgn) || 5000;
      const updatedVba = await korapayService.simulateIncomingBankTransfer(req.user!.userId, transferAmount);
      res.json({ success: true, message: `Successfully simulated ₦${transferAmount.toLocaleString()} transfer.`, data: updatedVba });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// ==========================================
// LIVING WALLET CORE ENDPOINTS
// ==========================================

// 1. Get Living Wallet Details (Main balance, Vault balance, Virtual NUBAN, 30-day Beneficiaries, Recent ledger)
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

// 2. Add Money / Fund Wallet (Card / Instant Bank Transfer)
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
      await db.createTransaction({
        id: `tx_fund_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        reference: `FUND_${Date.now()}`,
        user_id: req.user!.userId,
        amount_kobo: Math.round(amountNgn * 100),
        status: 'SUCCESS',
        payment_type: 'SUBSCRIPTION_PURCHASE',
        channel: req.body.channel || 'DIRECT_TRANSFER',
        meta_data: { type: 'WALLET_TOPUP', method: req.body.method || 'BANK_TRANSFER' },
        created_at: new Date().toISOString(),
      });

      // Push & In-App Notification on Wallet Credit
      oneSignalService.sendPush({
        userIds: [req.user!.userId],
        heading: 'Living Wallet Credited 💰',
        content: `₦${amountNgn.toLocaleString()} has been added to your Giga Wallet.`,
        data: { type: 'WALLET_CREDIT', amountNgn },
      }).catch(() => {});

      db.createNotification({
        user_id: req.user!.userId,
        title: 'Wallet Funded',
        message: `₦${amountNgn.toLocaleString()} was successfully added to your Living Wallet.`,
        type: 'WALLET',
        meta_data: { amountNgn },
      }).catch(() => {});

      res.json({
        success: true,
        message: `Successfully credited ₦${amountNgn.toLocaleString()} to Living Wallet.`,
        data: updated,
      });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// 3. Swap: Move funds between Main Ride Balance and SafeLock Vault
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

// 4. Withdraw: Instant NIP transfer to commercial bank with 30-day auto-beneficiary memory
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

      if (!amountNgn || !bankName || !accountNumber || !accountName) {
        res.status(400).json({ success: false, message: 'Missing required bank payout details.' });
        return;
      }

      const result = await db.withdrawFromWallet(req.user!.userId, amountNgn, {
        bankName: String(bankName),
        accountNumber: String(accountNumber),
        accountName: String(accountName),
        bankCode: String(bankCode || '000'),
      });

      res.json({
        success: true,
        message: `₦${Number(amountNgn).toLocaleString()} withdrawal dispatched to ${bankName} (${accountNumber}). Beneficiary auto-saved.`,
        data: result,
      });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// 5. Beneficiaries Directory: List / Search 30-Day Auto-Saved Beneficiaries
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

// 6. Explicitly Save / Pin Beneficiary
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

// 7. Delete Saved Beneficiary
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

// 8. Statement: Ledger Feed with Search & Inflow/Outflow Filter
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


// ==========================================
// SAVED CARDS & CARD TRANSACTIONS
// ==========================================

// 9. Get user's saved cards
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

// 10. Delete a saved card
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

// 11. Set default card
paymentRouter.post(
  '/cards/:id/default',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const cardId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const card = await db.setDefaultSavedCard(req.user!.userId, cardId);
      res.json({ success: true, message: 'Default card updated.', data: card });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// 12. Get Card Transactions only
paymentRouter.get(
  '/cards/transactions',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const cardTxs = await db.getCardTransactions(req.user!.userId);
      res.json({ success: true, data: cardTxs });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
);

// 13. Initialize Paystack card payment (for funding wallet or purchasing subscription)
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

      const result = await paystackService.initializeCardFunding(
        req.user!.userId,
        amountNgn,
        req.user!.email
      );

      res.json({ success: true, data: result });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// 14. 1-Click Instant Debit on Saved Card
paymentRouter.post(
  '/cards/charge-saved',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { cardId, amountNgn, purpose, planId } = req.body;
      if (!cardId || !amountNgn) {
        res.status(400).json({ success: false, message: 'cardId and amountNgn are required.' });
        return;
      }

      const result = await paystackService.chargeSavedCard(
        req.user!.userId,
        String(cardId),
        Number(amountNgn),
        purpose || 'WALLET_FUNDING',
        planId
      );

      res.json({ success: true, data: result });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// 15. Verify Card Transaction by Reference
paymentRouter.post(
  '/cards/verify',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { reference } = req.body;
      if (!reference) {
        res.status(400).json({ success: false, message: 'Transaction reference is required.' });
        return;
      }

      const result = await paystackService.verifyCardTransaction(String(reference));
      res.json(result);
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);

// 16. Peer-to-Peer Wallet Transfer (With 3-Month Auto-Beneficiary)
paymentRouter.post(
  '/wallet/transfer-p2p',
  requireAuth,
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { recipientSearch, amountNgn, saveAsBeneficiary } = req.body;
      if (!recipientSearch || !amountNgn) {
        res.status(400).json({ success: false, message: 'Recipient identifier and amount are required.' });
        return;
      }

      const result = await db.transferP2PWallet(
        req.user!.userId,
        String(recipientSearch),
        Number(amountNgn),
        saveAsBeneficiary !== false
      );

      res.json({
        success: true,
        message: `Successfully transferred ₦${Number(amountNgn).toLocaleString()} to ${result.recipientName}.`,
        data: result,
      });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
);
