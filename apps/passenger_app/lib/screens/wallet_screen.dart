import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
      final bens = await _api.getBeneficiaries(search: _beneficiarySearchCtrl.text.trim(), days: 30);
      final stmts = await _api.getStatement();

      if (mounted) {
        setState(() {
          _walletData = data;
          _beneficiaries = bens;
          _statement = stmts;
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
  // ACTION 1: ADD MONEY (FUND WALLET)
  // ==========================================
  void _showAddMoneyModal() {
    final vba = _walletData?['virtualAccount'];
    final nuban = vba?['account_number'] ?? '9988776655';
    final bank = vba?['bank_name'] ?? 'Wema Bank (Giga Dedicated)';
    final name = vba?['account_name'] ?? 'Giga Passenger';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Money to Living Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.darkBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dedicated Bank Transfer', style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Instant NIP • 24/7', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Bank Name', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    Text(bank, style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text('Account Number', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(nuban, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
                        IconButton(
                          icon: const Icon(Icons.copy, color: AppConstants.primaryColor, size: 20),
                          onPressed: () => _copyToClipboard(nuban, 'Account number'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Account Name', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    Text(name, style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Or Quick Top-Up (Direct Deposit):', style: TextStyle(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [2000, 5000, 10000, 20000].map((amt) {
                  return ActionChip(
                    backgroundColor: AppConstants.darkBg,
                    label: Text(_currencyFormat.format(amt), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _api.addMoney(amt);
                        _loadWalletData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Successfully deposited ${_currencyFormat.format(amt)}!'), backgroundColor: AppConstants.successColor),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: AppConstants.dangerColor),
                          );
                        }
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // ACTION 2: SWAP (MAIN <-> VAULT)
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
                  const Text('Swap Direction', style: TextStyle(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
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
  // ACTION 3: WITHDRAW WITH 30-DAY BENEFICIARIES
  // ==========================================
  void _showWithdrawModal({dynamic prefillBeneficiary}) {
    final amountCtrl = TextEditingController(text: '5000');
    final bankCtrl = TextEditingController(text: prefillBeneficiary?['bank_name'] ?? 'Access Bank');
    final accountCtrl = TextEditingController(text: prefillBeneficiary?['account_number'] ?? '');
    final nameCtrl = TextEditingController(text: prefillBeneficiary?['account_name'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
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
                    const Text('Withdraw to Bank Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                    IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Funds will be sent via instant NIP. Beneficiary is automatically remembered for 1 month.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                const SizedBox(height: 16),

                // 30-Day Beneficiaries Quick Pick Carousel
                if (_beneficiaries.isNotEmpty) ...[
                  const Text('Select Auto-Remembered Beneficiary (Last 30 Days):', style: TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _beneficiaries.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final b = _beneficiaries[idx];
                        return InkWell(
                          onTap: () {
                            bankCtrl.text = b['bank_name'] ?? '';
                            accountCtrl.text = b['account_number'] ?? '';
                            nameCtrl.text = b['account_name'] ?? '';
                          },
                          child: Container(
                            width: 140,
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
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Withdrawal Amount (₦)',
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
                    labelText: 'Commercial Bank (e.g. GTBank, Kuda, Zenith)',
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amt < 500 || accountCtrl.text.trim().length != 10 || nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid 10-digit NUBAN and min ₦500 amount.'), backgroundColor: AppConstants.dangerColor),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await _api.withdrawFromWallet(
                          amountNgn: amt,
                          bankName: bankCtrl.text.trim(),
                          accountNumber: accountCtrl.text.trim(),
                          accountName: nameCtrl.text.trim(),
                        );
                        _loadWalletData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Withdrawal of ${_currencyFormat.format(amt)} queued via NIP!'), backgroundColor: AppConstants.successColor),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: AppConstants.dangerColor),
                          );
                        }
                      }
                    },
                    child: const Text('Authorize Withdrawal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // ACTION 4: STATEMENT MODAL
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
          initialChildSize: 0.8,
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
                      const Text('Living Statement Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textLight)),
                      IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Text('Complete immutable ledger of all wallet inflows, outflows, and swaps.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
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
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: isOutflow ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                  child: Icon(isOutflow ? Icons.arrow_upward : Icons.arrow_downward, color: isOutflow ? Colors.redAccent : Colors.greenAccent, size: 18),
                                ),
                                title: Text(item['reference'] ?? 'Transaction', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(item['created_at']?.toString().split('T')[0] ?? '', style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
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
  // ACTION 5: VAULT MANAGEMENT MODAL
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
    final nuban = vba?['account_number'] ?? '9988776655';
    final bankName = vba?['bank_name'] ?? 'Wema Bank (Giga Dedicated)';

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
                // 1. LIVING WALLET GRADIENT HERO CARD
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
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                              ),
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
                      // NUBAN Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bankName, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                Text(nuban, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)),
                              ],
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.copy, size: 12, color: Colors.white),
                              label: const Text('Copy', style: TextStyle(fontSize: 10, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: const Size(60, 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _copyToClipboard(nuban, 'Account number'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. THE 5 CORE LIVING ACTION PILLARS
                const Text('Living Actions', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionItem(Icons.add_circle, 'Add Money', Colors.tealAccent, _showAddMoneyModal),
                    _buildActionItem(Icons.swap_horiz, 'Swap', Colors.lightBlueAccent, _showSwapModal),
                    _buildActionItem(Icons.arrow_upward, 'Withdraw', Colors.amberAccent, _showWithdrawModal),
                    _buildActionItem(Icons.receipt_long, 'Statement', Colors.purpleAccent, _showStatementModal),
                    _buildActionItem(Icons.lock, 'Vault', const Color(0xFF34D399), _showVaultModal),
                  ],
                ),

                const SizedBox(height: 28),

                // 3. 30-DAY AUTO-REMEMBERED BENEFICIARIES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saved Beneficiaries', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Auto-saved for 1 month', style: TextStyle(color: AppConstants.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Bar for Beneficiaries
                TextField(
                  controller: _beneficiarySearchCtrl,
                  onChanged: (val) async {
                    final bens = await _api.getBeneficiaries(search: val.trim(), days: 30);
                    if (mounted) setState(() => _beneficiaries = bens);
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search beneficiaries by name, NUBAN, or bank...',
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
                      child: Text('No saved beneficiaries found. Everyone you send money to is automatically remembered here for 30 days.',
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
                          onTap: () => _showWithdrawModal(prefillBeneficiary: b),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 155,
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

                // 4. RECENT ACTIVITY PREVIEW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Ledger Statement', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: _showStatementModal,
                      child: const Text('View All', style: TextStyle(color: AppConstants.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_statement.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('No recent activity recorded.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _statement.take(5).length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = _statement[idx];
                      final amountNgn = ((item['amount_kobo'] ?? 0) / 100).round();
                      final channel = item['channel'] ?? 'WALLET';
                      final isOutflow = channel == 'NIP_TRANSFER' || (item['meta_data']?['type'] == 'FARE_PAYMENT');

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
                                  backgroundColor: isOutflow ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                  child: Icon(isOutflow ? Icons.arrow_upward : Icons.arrow_downward, color: isOutflow ? Colors.redAccent : Colors.greenAccent, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['reference'] ?? 'Transaction', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text(item['created_at']?.toString().split('T')[0] ?? '', style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '${isOutflow ? '-' : '+'}${_currencyFormat.format(amountNgn)}',
                              style: TextStyle(color: isOutflow ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
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
