import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  final bool isTab;
  const WalletScreen({super.key, this.isTab = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _api = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  bool _isLoading = true;
  bool _hideBalance = false;
  Map<String, dynamic>? _walletData;
  List<dynamic> _beneficiaries = [];
  List<dynamic> _statement = [];
  List<dynamic> _savedCards = [];
  String _selectedLedgerFilter = 'ALL'; // 'ALL', 'CARDS', 'TRANSFERS'

  final TextEditingController _beneficiarySearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  @override
  void dispose() {
    _beneficiarySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getLivingWallet();
      final bens = await _api.getBeneficiaries(search: _beneficiarySearchCtrl.text.trim(), days: 90);
      final stmts = await _api.getStatement();
      final cards = await _api.getSavedCards();
      
      if (mounted) {
        setState(() {
          _walletData = data;
          _beneficiaries = bens;
          _statement = stmts;
          _savedCards = cards;
                    _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wallet: $e'), backgroundColor: AppConstants.dangerColor),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppConstants.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================
  // ACTION 1: ADD MONEY (CARD & BANK MODAL)
  // ==========================================
  void _showAddMoneyModal() {
    int selectedTab = 0; // 0 = Card, 1 = Bank Transfer
    final amountCtrl = TextEditingController(text: '5000');
    Map<String, dynamic>? dynamicTransfer;
    bool isGenerating = false;
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fund Living Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                        IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Method Selector Tabs
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedTab == 0 ? AppConstants.primaryColor : AppConstants.darkBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selectedTab == 0 ? AppConstants.primaryLight : Colors.white10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.credit_card_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Debit / Credit Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedTab == 1 ? AppConstants.primaryColor : AppConstants.darkBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selectedTab == 1 ? AppConstants.primaryLight : Colors.white10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Bank Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (selectedTab == 0) ...[
                      // CARD FUNDING TAB
                      if (_savedCards.isNotEmpty) ...[
                        const Text('Quick Top-Up with Saved Card:', style: TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ..._savedCards.map((c) {
                          final brand = (c['card_brand'] ?? 'card').toString().toUpperCase();
                          final last4 = c['card_last4'] ?? '••••';
                          final bankName = c['card_bank'] ?? 'Bank';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppConstants.darkBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                      child: Text(brand, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('•••• •••• •••• $last4', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                                        Text(bankName, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(64, 32)),
                                  onPressed: () => _chargeCardQuick(c['id'], int.tryParse(amountCtrl.text.trim()) ?? 5000, ctx),
                                  child: const Text('Charge', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Amount to Fund (₦)',
                          labelStyle: const TextStyle(color: AppConstants.textMuted),
                          prefixText: '₦ ',
                          prefixStyle: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold),
                          filled: true,
                          fillColor: AppConstants.darkBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        children: [2000, 5000, 10000, 25000].map((amt) {
                          return ActionChip(
                            backgroundColor: AppConstants.darkBg,
                            label: Text(_currencyFormat.format(amt), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => setModalState(() => amountCtrl.text = amt.toString()),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.lock_outline, size: 16, color: Colors.white),
                          label: const Text('Pay with Card (Paystack Checkout)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () async {
                            final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                            if (amt < 100) return;
                            Navigator.pop(ctx);
                            _initiatePaystackCardFunding(amt);
                          },
                        ),
                      ),
                    ] else ...[
                      // BANK TRANSFER TAB (DYNAMIC PAYSTACK BANK ACCOUNT)
                      if (dynamicTransfer == null) ...[
                        const Text(
                          'Paystack Dynamic Bank Transfer',
                          style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'A temporary, one-time Paystack bank account is generated for this transfer. Funds are automatically credited to your Naira wallet once received.',
                          style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Deposit Amount (₦)',
                            labelStyle: const TextStyle(color: AppConstants.textMuted),
                            prefixText: '₦ ',
                            prefixStyle: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: AppConstants.darkBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [2000, 5000, 10000, 25000].map((amt) {
                            return ActionChip(
                              backgroundColor: AppConstants.darkBg,
                              label: Text(_currencyFormat.format(amt), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => setModalState(() => amountCtrl.text = amt.toString()),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: isGenerating
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.account_balance_rounded, size: 18, color: Colors.white),
                            label: Text(
                              isGenerating ? 'Generating Account...' : 'Get Dynamic Transfer Account',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isGenerating ? null : () async {
                              final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                              if (amt < 100) return;
                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() => isGenerating = true);
                              try {
                                final res = await _api.generateDynamicBankTransfer(amt);
                                setModalState(() {
                                  dynamicTransfer = res;
                                  isGenerating = false;
                                });
                              } catch (e) {
                                setModalState(() => isGenerating = false);
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: AppConstants.dangerColor),
                                );
                              }
                            },
                          ),
                        ),
                      ] else ...[
                        // DYNAMIC ACCOUNT DETAILS CARD
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppConstants.darkBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Paystack Dynamic Account', style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.timer_outlined, size: 12, color: Colors.amberAccent),
                                        SizedBox(width: 4),
                                        Text('Expires in 30 mins', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text('Bank Name', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                              Text(dynamicTransfer!['bankName'] ?? 'Wema Bank / Paystack', style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              const Text('Dynamic Account Number', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dynamicTransfer!['accountNumber'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: AppConstants.primaryColor, size: 20),
                                    onPressed: () => _copyToClipboard(dynamicTransfer!['accountNumber'] ?? '', 'Dynamic account number'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text('Account Name', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                              Text(dynamicTransfer!['accountName'] ?? 'Paystack / Giga Ride', style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 8),
                              const Text('Amount to Pay Exactly', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                              Text(
                                _currencyFormat.format(dynamicTransfer!['amountNgn'] ?? 0),
                                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: isVerifying
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                            label: Text(
                              isVerifying ? 'Confirming Transfer...' : 'I Have Sent The Money',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.successColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isVerifying ? null : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() => isVerifying = true);
                              final ref = dynamicTransfer!['reference'] as String;
                              try {
                                await _api.verifyDynamicBankTransfer(ref);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (mounted) await _loadWalletData();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✓ ${_currencyFormat.format(dynamicTransfer!['amountNgn'] ?? 0)} successfully credited to your Living Wallet!'),
                                    backgroundColor: AppConstants.successColor,
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => isVerifying = false);
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Confirmation: $e'), backgroundColor: AppConstants.dangerColor),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: () => setModalState(() => dynamicTransfer = null),
                            child: const Text('Cancel / Choose Different Amount', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Execute 1-click charge on saved card
  Future<void> _chargeCardQuick(String cardId, int amountNgn, BuildContext modalCtx) async {
    Navigator.pop(modalCtx);
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _api.chargeSavedCard(cardId: cardId, amountNgn: amountNgn);
      await _loadWalletData();
      messenger.showSnackBar(
        SnackBar(content: Text('✓ ${res['message'] ?? "Card charged successfully!"}'), backgroundColor: AppConstants.successColor),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppConstants.dangerColor),
      );
    }
  }

  // Initiate Paystack card checkout
  Future<void> _initiatePaystackCardFunding(int amountNgn) async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final initData = await _api.initializeCardFunding(amountNgn);
      final authUrl = initData['authorizationUrl'] as String?;
      final ref = initData['reference'] as String?;

      if (authUrl != null && await canLaunchUrl(Uri.parse(authUrl))) {
        await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
      }

      // Verify transaction reference to capture card token and update balance
      if (ref != null) {
        await _api.verifyCardTransaction(ref);
      }

      await _loadWalletData();
      messenger.showSnackBar(
        SnackBar(content: Text('✓ ₦${NumberFormat('#,##0', 'en_US').format(amountNgn)} card deposit captured and credited!'), backgroundColor: AppConstants.successColor),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Card funding error: $e'), backgroundColor: AppConstants.dangerColor),
      );
    }
  }

  // ==========================================
  // ACTION 2: MY CARDS MODAL
  // ==========================================
  void _showCardsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saved Debit & Credit Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                      IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Text('Cards saved for instant 1-click wallet funding and subscription renewals.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                  const SizedBox(height: 16),

                  if (_savedCards.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppConstants.darkBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                      child: const Column(
                        children: [
                          Icon(Icons.credit_card_off_rounded, color: AppConstants.textMuted, size: 40),
                          SizedBox(height: 10),
                          Text('No saved cards found.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Cards used during Paystack funding are automatically saved here securely.', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  else
                    ..._savedCards.map((c) {
                      final brand = (c['card_brand'] ?? 'visa').toString().toUpperCase();
                      final last4 = c['card_last4'] ?? '••••';
                      final bankName = c['card_bank'] ?? 'Commercial Bank';
                      final exp = '${c['exp_month'] ?? "12"}/${c['exp_year'] ?? "28"}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(bankName, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                  child: Text(brand, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text('•••• •••• •••• $last4', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Expires $exp', style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppConstants.dangerColor, size: 18),
                                  onPressed: () async {
                                    final confirmed = await _api.deleteSavedCard(c['id']);
                                    if (confirmed && ctx.mounted) {
                                      Navigator.pop(ctx);
                                      if (mounted) _loadWalletData();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 18),
                      label: const Text('Add New Card (Verify via Paystack)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _initiatePaystackCardFunding(100);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ACTION 3: TRANSFER WITH 3-MONTH BENEFICIARY SEARCH
  // ==========================================
  void _showTransferModal({dynamic prefillBeneficiary}) {
    final amountCtrl = TextEditingController(text: '5000');
    final bankCtrl = TextEditingController(text: prefillBeneficiary?['bank_name'] ?? 'Access Bank');
    final accountCtrl = TextEditingController(text: prefillBeneficiary?['account_number'] ?? '');
    final nameCtrl = TextEditingController(text: prefillBeneficiary?['account_name'] ?? '');
    final searchCtrl = TextEditingController();
    bool saveBeneficiary = true;
    List<dynamic> filteredRecipients = List.from(_beneficiaries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Send / Transfer Money', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                        IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Transfers sent to Nigerian commercial banks or Giga riders. Recipients are remembered for 3 months.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    const SizedBox(height: 14),

                    // 3-MONTH BENEFICIARY SEARCH BAR
                    TextField(
                      controller: searchCtrl,
                      onChanged: (query) {
                        setModalState(() {
                          final q = query.trim().toLowerCase();
                          if (q.isEmpty) {
                            filteredRecipients = List.from(_beneficiaries);
                          } else {
                            filteredRecipients = _beneficiaries.where((b) {
                              final name = (b['account_name'] ?? '').toString().toLowerCase();
                              final acc = (b['account_number'] ?? '').toString().toLowerCase();
                              final bank = (b['bank_name'] ?? '').toString().toLowerCase();
                              return name.contains(q) || acc.contains(q) || bank.contains(q);
                            }).toList();
                          }
                        });
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search past recipients (3 months history)...',
                        hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: AppConstants.accentColor, size: 18),
                        filled: true,
                        fillColor: AppConstants.darkBg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filtered Past Recipients Carousel
                    if (filteredRecipients.isNotEmpty) ...[
                      const Text('Quick Select Past Recipient (Click to Auto-fill):', style: TextStyle(color: AppConstants.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredRecipients.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final b = filteredRecipients[idx];
                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  bankCtrl.text = b['bank_name'] ?? '';
                                  accountCtrl.text = b['account_number'] ?? '';
                                  nameCtrl.text = b['account_name'] ?? '';
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 145,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppConstants.darkBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(b['account_name'] ?? 'Recipient', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    Text(b['bank_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                    Text(b['account_number'] ?? '', style: const TextStyle(color: AppConstants.accentColor, fontSize: 10, fontFamily: 'monospace')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Transfer Amount (₦)',
                        labelStyle: const TextStyle(color: AppConstants.textMuted),
                        filled: true,
                        fillColor: AppConstants.darkBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bankCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Destination Bank (e.g. GTBank, Kuda, Zenith, Access)',
                        labelStyle: const TextStyle(color: AppConstants.textMuted),
                        filled: true,
                        fillColor: AppConstants.darkBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: accountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: '10-Digit NUBAN Account Number',
                        labelStyle: const TextStyle(color: AppConstants.textMuted),
                        filled: true,
                        fillColor: AppConstants.darkBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Account Holder Full Name',
                        labelStyle: const TextStyle(color: AppConstants.textMuted),
                        filled: true,
                        fillColor: AppConstants.darkBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Save Beneficiary Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: saveBeneficiary,
                          activeColor: AppConstants.accentColor,
                          onChanged: (v) => setModalState(() => saveBeneficiary = v ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Remember this beneficiary for up to 3 months',
                            style: TextStyle(color: AppConstants.textLight, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (amt < 500 || accountCtrl.text.trim().length != 10 || nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter valid 10-digit NUBAN and minimum ₦500 amount.'), backgroundColor: AppConstants.dangerColor),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _api.withdrawFromWallet(
                              amountNgn: amt,
                              bankName: bankCtrl.text.trim(),
                              accountNumber: accountCtrl.text.trim(),
                              accountName: nameCtrl.text.trim(),
                            );
                            _loadWalletData();
                            messenger.showSnackBar(
                              SnackBar(content: Text('✓ ₦${_currencyFormat.format(amt)} transfer dispatched! Recipient remembered for 3 months.'), backgroundColor: AppConstants.successColor),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: AppConstants.dangerColor),
                            );
                          }
                        },
                        child: const Text('Authorize Instant Transfer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ACTION 4: SWAP (MAIN <-> VAULT)
  // ==========================================
  void _showSwapModal() {
    String direction = 'MAIN_TO_VAULT';
    final amountCtrl = TextEditingController(text: '5000');
    final vba = _walletData?['virtualAccount'];
    final mainBal = (vba?['balance_ngn'] ?? 0) as num;
    final vaultBal = (vba?['vault_balance_ngn'] ?? 0) as num;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Swap Funds (Main ⇄ Vault)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                      IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppConstants.darkBg, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Main Balance', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                            Text(_currencyFormat.format(mainBal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const Icon(Icons.swap_horiz, color: AppConstants.accentColor),
                        Column(
                          children: [
                            const Text('Vault SafeLock', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                            Text(_currencyFormat.format(vaultBal), style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('To SafeLock Vault', style: TextStyle(fontSize: 12)),
                          selected: direction == 'MAIN_TO_VAULT',
                          selectedColor: AppConstants.primaryColor,
                          onSelected: (val) => setModalState(() => direction = 'MAIN_TO_VAULT'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('To Main Wallet', style: TextStyle(fontSize: 12)),
                          selected: direction == 'VAULT_TO_MAIN',
                          selectedColor: AppConstants.primaryColor,
                          onSelected: (val) => setModalState(() => direction = 'VAULT_TO_MAIN'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Amount (₦)',
                      labelStyle: const TextStyle(color: AppConstants.textMuted),
                      prefixText: '₦ ',
                      prefixStyle: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: AppConstants.darkBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                        if (amt <= 0) return;
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _api.swapWalletVault(direction, amt);
                          _loadWalletData();
                          messenger.showSnackBar(
                            SnackBar(content: Text('Swap successful: ${_currencyFormat.format(amt)} moved!'), backgroundColor: AppConstants.successColor),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: AppConstants.dangerColor),
                          );
                        }
                      },
                      child: const Text('Confirm Swap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ACTION 5: STATEMENT MODAL
  // ==========================================
  void _showStatementModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Living Statement & Card Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                      IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Text('Complete immutable ledger of all wallet inflows, card transactions, and payouts.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _statement.isEmpty
                        ? const Center(child: Text('No transactions recorded yet.', style: TextStyle(color: AppConstants.textMuted)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: _statement.length,
                            separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                            itemBuilder: (context, idx) {
                              final item = _statement[idx];
                              final amountNgn = ((item['amount_kobo'] ?? 0) / 100).round();
                              final channel = item['channel'] ?? 'WALLET';
                              final isOutflow = channel == 'NIP_TRANSFER' || (item['meta_data']?['type'] == 'FARE_PAYMENT');
                              final isCard = channel.toString().contains('card') || item['card_last4'] != null;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: isCard ? Colors.blueAccent.withOpacity(0.15) : isOutflow ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                  child: Icon(
                                    isCard ? Icons.credit_card_rounded : isOutflow ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: isCard ? Colors.cyanAccent : isOutflow ? Colors.redAccent : Colors.greenAccent,
                                    size: 18,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isCard ? 'Card Deposit • ${item['card_brand']?.toString().toUpperCase() ?? "CARD"} •••• ${item['card_last4'] ?? ""}' : (item['reference'] ?? 'Transaction'),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item['status'] == 'SUCCESS')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                        child: const Text('SUCCESS', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${item['card_bank'] ?? channel} • ${item['created_at']?.toString().split('T')[0] ?? ""}',
                                  style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                ),
                                trailing: Text(
                                  '${isOutflow ? '-' : '+'}${_currencyFormat.format(amountNgn)}',
                                  style: TextStyle(color: isOutflow ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ACTION 6: VAULT MODAL
  // ==========================================
  void _showVaultModal() {
    final vba = _walletData?['virtualAccount'];
    final vaultBal = (vba?['vault_balance_ngn'] ?? 0) as num;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 48),
              const SizedBox(height: 12),
              const Text('Giga SafeLock Vault', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Funds stored in your SafeLock Vault are shielded from trip auto-debit. Use it to lock ride budgets or save for airport/interstate commutes.', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppConstants.darkBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.teal.withOpacity(0.3))),
                child: Column(
                  children: [
                    const Text('Total Locked Vault Balance', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_currencyFormat.format(vaultBal), style: const TextStyle(color: Colors.tealAccent, fontSize: 26, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open, color: Colors.white, size: 16),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSwapModal();
                      },
                      label: const Text('Unlock Funds', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock, color: Colors.white, size: 16),
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSwapModal();
                      },
                      label: const Text('Lock Funds', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppConstants.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
      );
    }

    final vba = _walletData?['virtualAccount'];
    final mainBal = (vba?['balance_ngn'] ?? 0) as num;
    final vaultBal = (vba?['vault_balance_ngn'] ?? 0) as num;

    // Filter statement by user selection
    final displayStatement = _selectedLedgerFilter == 'CARDS'
        ? _statement.where((t) => t['channel'].toString().contains('card') || t['card_last4'] != null).toList()
        : _selectedLedgerFilter == 'TRANSFERS'
            ? _statement.where((t) => t['channel'] == 'NIP_TRANSFER' || t['channel'] == 'P2P_TRANSFER').toList()
            : _statement;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTab,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Living Wallet', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_hideBalance ? Icons.visibility_off : Icons.visibility, color: AppConstants.textMuted),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppConstants.textMuted),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWalletData,
          color: AppConstants.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO WALLET GRADIENT CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.teal.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('Active Living Wallet', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shield, color: Colors.tealAccent, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  _hideBalance ? '••••' : 'Vault: ${_currencyFormat.format(vaultBal)}',
                                  style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Total Available Balance', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _hideBalance ? '₦ ••••••••' : _currencyFormat.format(mainBal),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 16),
                      // Clean Digital Wallet Security Badge (No permanent bank account)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: AppConstants.accentColor, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Digital Naira Wallet • Pay via Card or Dynamic Bank Transfer',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. CORE ACTION PILLARS
                const Text('Living Actions', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionItem(Icons.add_circle_outline, 'Add Money', Colors.tealAccent, _showAddMoneyModal),
                    _buildActionItem(Icons.credit_card_rounded, 'My Cards', Colors.cyanAccent, _showCardsModal),
                    _buildActionItem(Icons.send_rounded, 'Transfer', Colors.amberAccent, _showTransferModal),
                    _buildActionItem(Icons.lock_rounded, 'Vault', const Color(0xFF34D399), _showVaultModal),
                    _buildActionItem(Icons.receipt_long, 'Ledger', Colors.purpleAccent, _showStatementModal),
                  ],
                ),

                const SizedBox(height: 28),

                // 3. 3-MONTH LIVING RECIPIENTS MEMORY & SEARCH
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Past Transfer Recipients', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Text('3 Months Memory', style: TextStyle(color: AppConstants.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Bar for Past Recipients
                TextField(
                  controller: _beneficiarySearchCtrl,
                  onChanged: (val) async {
                    final bens = await _api.getBeneficiaries(search: val.trim(), days: 90);
                    if (mounted) setState(() => _beneficiaries = bens);
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search people by name, bank, or NUBAN...',
                    hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: AppConstants.textMuted, size: 18),
                    filled: true,
                    fillColor: AppConstants.cardBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                if (_beneficiaries.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16)),
                    child: const Center(
                      child: Text('No past recipients found. Every person you transfer money to is held for 3 months so you can click and send easily.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    ),
                  )
                else
                  SizedBox(
                    height: 95,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _beneficiaries.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (context, idx) {
                        final b = _beneficiaries[idx];
                        final name = b['account_name'] ?? 'Recipient';
                        final bank = b['bank_name'] ?? 'Bank';
                        final num = b['account_number'] ?? '';
                        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';

                        return InkWell(
                          onTap: () => _showTransferModal(prefillBeneficiary: b),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppConstants.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppConstants.primaryColor.withOpacity(0.2),
                                  child: Text(initial, style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text(bank, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                      Text(num, style: const TextStyle(color: AppConstants.accentColor, fontSize: 10, fontFamily: 'monospace')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 28),

                // 4. RECENT LEDGER & CARD TRANSACTIONS FEED
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Ledger & Cards', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: _showStatementModal,
                      child: const Text('View All', style: TextStyle(color: AppConstants.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Filter Chips
                Row(
                  children: [
                    _buildFilterChip('ALL', 'All Transactions'),
                    const SizedBox(width: 8),
                    _buildFilterChip('CARDS', '💳 Card Only'),
                    const SizedBox(width: 8),
                    _buildFilterChip('TRANSFERS', '🏦 Transfers'),
                  ],
                ),
                const SizedBox(height: 10),

                if (displayStatement.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('No transactions recorded for this filter.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayStatement.take(6).length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = displayStatement[idx];
                      final amountNgn = ((item['amount_kobo'] ?? 0) / 100).round();
                      final channel = item['channel'] ?? 'WALLET';
                      final isOutflow = channel == 'NIP_TRANSFER' || channel == 'P2P_TRANSFER' || (item['meta_data']?['type'] == 'FARE_PAYMENT');
                      final isCard = channel.toString().contains('card') || item['card_last4'] != null;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isCard ? Colors.blueAccent.withOpacity(0.15) : isOutflow ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                  child: Icon(
                                    isCard ? Icons.credit_card_rounded : isOutflow ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: isCard ? Colors.cyanAccent : isOutflow ? Colors.redAccent : Colors.greenAccent,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCard ? 'Card Deposit • ${item['card_brand']?.toString().toUpperCase() ?? "CARD"} •••• ${item['card_last4'] ?? ""}' : (item['reference'] ?? 'Transaction'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    Text(
                                      '${item['card_bank'] ?? channel} • ${item['created_at']?.toString().split('T')[0] ?? ""}',
                                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isOutflow ? '-' : '+'}${_currencyFormat.format(amountNgn)}',
                                  style: TextStyle(color: isOutflow ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if (isCard)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('CARD SUCCESS', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedLedgerFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppConstants.textMuted, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: AppConstants.primaryColor,
      backgroundColor: AppConstants.cardBg,
      onSelected: (_) => setState(() => _selectedLedgerFilter = key),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
