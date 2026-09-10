import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import '../services/api_service.dart';
import '../services/statement_pdf_service.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _savedCards = [];
  List<dynamic> _cardTransactions = [];
  List<dynamic> _statement = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().loadVirtualAccount();
      _loadCardsAndTransactions();
    });
  }

  Future<void> _loadCardsAndTransactions() async {
    try {
      final cards = await _api.getSavedCards();
      final txs = await _api.getCardTransactions();
      final stmt = await _api.getStatement();
      if (mounted) {
        setState(() {
          _savedCards = cards;
          _cardTransactions = txs;
          _statement = stmt;
        });
      }
    } catch (_) {}
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard!'), backgroundColor: AppConstants.successColor),
    );
  }

  void _showWithdrawModal() {
    int withdrawMode = 0; // 0 = Bank Account (NIP), 1 = USDT Crypto (Maplerad)
    final amountCtrl = TextEditingController(text: '10000');
    final accountNumCtrl = TextEditingController();
    final accountNameCtrl = TextEditingController(text: 'Driver Partner');
    final bankCtrl = TextEditingController(text: 'GTBank (Guaranty Trust)');
    final cryptoAddressCtrl = TextEditingController();
    String cryptoNetwork = 'TRC20';
    int cryptoRateNgn = 1550;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final amt = int.tryParse(amountCtrl.text) ?? 10000;
          final feeNgn = 50 + (amt * 0.005).round();
          final totalNgn = amt + feeNgn;
          final estUsdt = (amt / cryptoRateNgn).toStringAsFixed(2);

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Withdraw Earnings', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Mode Selector: Bank vs USDT Crypto
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => withdrawMode = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: withdrawMode == 0 ? AppConstants.primaryColor : AppConstants.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: withdrawMode == 0 ? AppConstants.primaryLight : Colors.white10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_rounded, color: Colors.white, size: 15),
                                SizedBox(width: 6),
                                Text('Bank Account (NIP)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            setModalState(() => withdrawMode = 1);
                            try {
                              final r = await _api.getCryptoRate();
                              if (r['rateNgn'] != null) {
                                setModalState(() => cryptoRateNgn = (r['rateNgn'] as num).toInt());
                              }
                            } catch (_) {}
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: withdrawMode == 1 ? const Color(0xFF0D9488) : AppConstants.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: withdrawMode == 1 ? Colors.tealAccent : Colors.white10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.currency_bitcoin_rounded, color: Colors.tealAccent, size: 15),
                                SizedBox(width: 6),
                                Text('USDT Crypto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount to Withdraw (₦)',
                      prefixText: '₦ ',
                      filled: true,
                      fillColor: AppConstants.surfaceBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Fee breakdown (Strictly priced in Naira ₦)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppConstants.surfaceBg, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Platform Settlement Fee (₦50 + 0.5%):', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                            Text('₦${feeNgn.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Deducted from Balance:', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                            Text('₦${totalNgn.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (withdrawMode == 0) ...[
                    // COMMERCIAL BANK FIELDS
                    TextField(
                      controller: bankCtrl,
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Destination Bank',
                        filled: true,
                        fillColor: AppConstants.surfaceBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accountNumCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 16, letterSpacing: 2),
                      decoration: InputDecoration(
                        labelText: '10-Digit NUBAN Number',
                        hintText: '0123456789',
                        filled: true,
                        fillColor: AppConstants.surfaceBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ] else ...[
                    // USDT CRYPTO FIELDS
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_exchange_rounded, color: Colors.tealAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live Rate: 1 USDT ≈ ₦${cryptoRateNgn.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} | Dispatched: ≈ $estUsdt USDT',
                              style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      children: ['TRC20', 'BEP20', 'POLYGON'].map((net) {
                        final isSel = cryptoNetwork == net;
                        return ChoiceChip(
                          label: Text(net, style: TextStyle(color: isSel ? Colors.white : AppConstants.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          selected: isSel,
                          selectedColor: const Color(0xFF0D9488),
                          backgroundColor: AppConstants.surfaceBg,
                          onSelected: (_) => setModalState(() => cryptoNetwork = net),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: cryptoAddressCtrl,
                      style: const TextStyle(color: Colors.tealAccent, fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Destination USDT Wallet Address ($cryptoNetwork)',
                        hintText: cryptoNetwork == 'TRC20' ? 'T...' : '0x...',
                        filled: true,
                        fillColor: AppConstants.surfaceBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: withdrawMode == 1 ? const Color(0xFF0D9488) : AppConstants.successColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isProcessing ? null : () async {
                        if (amt < 500) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Minimum withdrawal is ₦500.'), backgroundColor: AppConstants.dangerColor),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() => isProcessing = true);

                        try {
                          if (withdrawMode == 0) {
                            final accNum = accountNumCtrl.text.trim();
                            if (accNum.length != 10) {
                              throw Exception('Please enter a valid 10-digit NUBAN number.');
                            }
                            await _api.withdrawToBank(
                              amountNgn: amt,
                              bankName: bankCtrl.text.trim(),
                              accountNumber: accNum,
                              accountName: accountNameCtrl.text.trim(),
                            );
                          } else {
                            final addr = cryptoAddressCtrl.text.trim();
                            if (addr.length < 15) {
                              throw Exception('Please enter a valid USDT destination address.');
                            }
                            await _api.withdrawCryptoUsdt(
                              amountNgn: amt,
                              targetAddress: addr,
                              network: cryptoNetwork,
                            );
                          }

                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (mounted) {
                            context.read<DriverProvider>().loadVirtualAccount();
                            _loadCardsAndTransactions();
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                withdrawMode == 0
                                    ? '✓ ₦${NumberFormat('#,##0', 'en_US').format(amt)} dispatched via NIP to your bank!'
                                    : '✓ $estUsdt USDT dispatched to your $cryptoNetwork crypto wallet!',
                              ),
                              backgroundColor: AppConstants.successColor,
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isProcessing = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Withdrawal Error: $e'), backgroundColor: AppConstants.dangerColor),
                          );
                        }
                      },
                      child: isProcessing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              withdrawMode == 0 ? 'Confirm Bank Transfer' : 'Dispatch $estUsdt USDT',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final vba = provider.virtualAccount;
    final todayGross = provider.todayGrossEarningsNgn;
    final completedCount = provider.todayCompletedTripsCount;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Earnings & Wallet', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppConstants.textMuted),
            onPressed: () {
              provider.loadVirtualAccount();
              _loadCardsAndTransactions();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await provider.loadVirtualAccount();
            await _loadCardsAndTransactions();
          },
          color: AppConstants.primaryColor,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Today's Gross Earnings Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Today\'s Gross Earnings', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                        Icon(Icons.trending_up_rounded, color: AppConstants.successColor, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${NumberFormat('#,##0', 'en_US').format(todayGross)}',
                      style: const TextStyle(color: AppConstants.accentColor, fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$completedCount trips completed today • 0% Commission Kept',
                      style: const TextStyle(color: AppConstants.successColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Dedicated Virtual Account Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF064E3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: AppConstants.primaryColor.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(vba?['bank_name'] ?? 'Wema Bank (Giga Dedicated)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Instant DVA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Your Dedicated NUBAN Number', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          vba != null ? (vba['account_number'] ?? 'Provisioning...') : 'Provisioning...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: vba != null ? 24 : 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: vba != null ? 3 : 1,
                          ),
                        ),
                        if (vba != null && vba['account_number'] != null)
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                            onPressed: () => _copyToClipboard(vba['account_number'], 'NUBAN Account Number'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vba?['account_name'] ?? (provider.user?['fullName'] ?? provider.user?['full_name'] ?? 'Driver Account'),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Available Withdrawable Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Instant NIP / Crypto Payout', style: TextStyle(color: Colors.white38, fontSize: 9)),
                          ],
                        ),
                        Text(
                          '₦${NumberFormat('#,##0', 'en_US').format((vba?['balance_ngn'] as num?)?.toInt() ?? 0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    if (vba?['usdt_address'] != null && (vba!['usdt_address'] as String).isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.currency_bitcoin_rounded, color: Colors.tealAccent, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Maplerad USDT Wallet (${vba['usdt_network'] ?? 'TRC20'})',
                                        style: const TextStyle(color: Colors.tealAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    vba['usdt_address'],
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.tealAccent, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _copyToClipboard(vba['usdt_address'], 'USDT Wallet Address'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Withdraw Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _showWithdrawModal,
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: const Text('Withdraw to Bank (Instant NIP)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),

              const SizedBox(height: 24),

              // SAVED CARDS ON FILE SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saved Cards & Auto-Debit', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('PCI-DSS Secure', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_savedCards.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.credit_card_outlined, color: AppConstants.textMuted, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cards used during subscription pack renewal are securely saved here for 1-tap top-ups and lockout protection.',
                          style: TextStyle(color: AppConstants.textMuted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._savedCards.map((c) {
                  final brand = (c['card_brand'] ?? 'visa').toString().toUpperCase();
                  final last4 = c['card_last4'] ?? '••••';
                  final bank = c['card_bank'] ?? 'Commercial Bank';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text(brand, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('•••• •••• •••• $last4', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
                                Text(bank, style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // TRANSACTIONS & STATEMENT LEDGER
              const Text('Statement & Transaction Ledger', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // Print & Share Official PDF Statement Action Bar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print Statement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final user = provider.user;
                        final allTxs = _statement.isNotEmpty ? _statement : _cardTransactions;
                        await StatementPdfService.printStatement(
                          userName: user?['fullName'] ?? user?['full_name'] ?? 'Giga Driver',
                          userEmail: user?['email'] ?? '',
                          userPhone: user?['phone_number'] ?? user?['phoneNumber'] ?? '',
                          currentBalanceNgn: (vba?['balance_ngn'] ?? 0) as num,
                          transactions: allTxs,
                          nuban: vba?['account_number'],
                          bankName: vba?['bank_name'],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConstants.accentColor,
                        side: const BorderSide(color: AppConstants.accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final user = provider.user;
                        final allTxs = _statement.isNotEmpty ? _statement : _cardTransactions;
                        await StatementPdfService.shareStatement(
                          userName: user?['fullName'] ?? user?['full_name'] ?? 'Giga Driver',
                          userEmail: user?['email'] ?? '',
                          userPhone: user?['phone_number'] ?? user?['phoneNumber'] ?? '',
                          currentBalanceNgn: (vba?['balance_ngn'] ?? 0) as num,
                          transactions: allTxs,
                          nuban: vba?['account_number'],
                          bankName: vba?['bank_name'],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_cardTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.history_rounded, color: AppConstants.textMuted, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No card transactions recorded yet. Subscription purchases and card top-ups will appear here in real-time.',
                          style: TextStyle(color: AppConstants.textMuted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cardTransactions.take(5).length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final tx = _cardTransactions[idx];
                    final amountNgn = ((tx['amount_kobo'] ?? 0) / 100).round();
                    final brand = (tx['card_brand'] ?? 'CARD').toString().toUpperCase();
                    final last4 = tx['card_last4'] ?? '';
                    final bank = tx['card_bank'] ?? 'Debit Card';

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
                                backgroundColor: Colors.blueAccent.withOpacity(0.15),
                                child: const Icon(Icons.credit_card_rounded, color: Colors.cyanAccent, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    last4.isNotEmpty ? '$brand •••• $last4' : (tx['reference'] ?? 'Card Payment'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    '$bank • ${tx['created_at']?.toString().split('T')[0] ?? ""}',
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
                                '₦${NumberFormat('#,##0', 'en_US').format(amountNgn)}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: const Text('SUCCESS', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
