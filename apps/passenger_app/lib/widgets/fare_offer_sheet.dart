import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import '../screens/offer_room_screen.dart';

/// FareOfferSheet — full-screen bottom sheet for fare selection.
/// Shows system-calculated fare, vehicle tier cards (each with own price),
/// large ±₦100 stepper, manual input, and broadcast CTA.
class FareOfferSheet extends StatefulWidget {
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double distanceKm;
  final int durationMins;
  final String? notes;
  final bool isBusiness;
  final String? riderName;
  final String? riderPhone;
  final String riderType;
  final String selectedCategory;

  const FareOfferSheet({
    super.key,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.distanceKm,
    required this.durationMins,
    this.notes,
    this.isBusiness = false,
    this.riderName,
    this.riderPhone,
    this.riderType = 'SELF',
    this.selectedCategory = 'CITY',
  });

  @override
  State<FareOfferSheet> createState() => _FareOfferSheetState();
}

class _FareOfferSheetState extends State<FareOfferSheet> {
  final currencyFormat =
      NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  String _selectedTier = 'ECONOMY';
  late int _offerAmount;
  late int _recommendedBase;
  late int _minimumFloor;
  final Map<String, int> _tierFares = {};
  bool _isLoading = false;
  bool _isBroadcasting = false;
  bool _addWaitTime = false;
  int _selectedWaitMinutes = 30;

  // Multipliers per tier
  static const Map<String, double> _multipliers = {
    'ECONOMY': 1.0,
    'COMFORT': 1.25,
    'XL_SUV': 1.70,
  };

  // Long-press repeat stepper
  Timer? _stepTimer;

  int _computeInstantBase(double km, int mins) {
    final dist = km > 0 ? km : 5.0;
    final dur = mins > 0 ? mins : 15;
    final raw = 1500 + (dist * 350) + (dur * 80);
    return ((raw / 100).round() * 100).clamp(1500, 200000);
  }

  @override
  void initState() {
    super.initState();
    final instantBase = _computeInstantBase(widget.distanceKm, widget.durationMins);
    _recommendedBase = instantBase;
    _minimumFloor = (instantBase * 0.70).round();
    _offerAmount = instantBase;
    _tierFares['ECONOMY'] = instantBase;
    _tierFares['COMFORT'] = (instantBase * 1.25).round();
    _tierFares['XL_SUV'] = (instantBase * 1.70).round();

    _loadEstimate();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEstimate() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<PassengerProvider>();
      await provider.calculateEstimate(
        pickupLat: widget.pickupLat,
        pickupLng: widget.pickupLng,
        dropoffLat: widget.dropoffLat,
        dropoffLng: widget.dropoffLng,
        distanceKm: widget.distanceKm,
        durationMinutes: widget.durationMins,
      );
      final est = provider.currentEstimate;
      if (est != null && mounted) {
        final base = (est['suggestedFareNgn'] ??
                est['recommendedFareNgn'] ??
                est['estimatedFareNgn'] ??
                _computeInstantBase(widget.distanceKm, widget.durationMins))
            as num;
        final floor = (est['minimumBidFloorNgn'] ?? (base * 0.70).round()) as num;
        final tiers = est['tiers'];
        if (tiers != null && tiers is Map) {
          _tierFares['ECONOMY'] = (tiers['economyFareNgn'] ?? base).toInt();
          _tierFares['COMFORT'] =
              (tiers['comfortFareNgn'] ?? (base * 1.25).round()).toInt();
          _tierFares['XL_SUV'] =
              (tiers['xlSuvFareNgn'] ?? (base * 1.70).round()).toInt();
        }
        setState(() {
          _recommendedBase = base.round();
          _minimumFloor = floor.round();
          _offerAmount = _tierAmount(_selectedTier);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  int _tierAmount(String tier) {
    if (_tierFares.containsKey(tier)) {
      return _tierFares[tier]!;
    }
    final mult = _multipliers[tier] ?? 1.0;
    return (_recommendedBase * mult).round();
  }

  void _selectTier(String tier) {
    setState(() {
      _selectedTier = tier;
      _offerAmount = _tierAmount(tier);
    });
    HapticFeedback.selectionClick();
  }

  void _step(int delta) {
    setState(() {
      _offerAmount = (_offerAmount + delta).clamp(_minimumFloor, 200000);
    });
    HapticFeedback.lightImpact();
  }

  void _startLongPress(int delta) {
    _step(delta);
    _stepTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted) _step(delta);
    });
  }

  void _stopLongPress() {
    _stepTimer?.cancel();
  }

  Future<void> _broadcastOffer() async {
    if (_offerAmount < _minimumFloor) {
      _showSnack(
          'Minimum fare floor is ${currencyFormat.format(_minimumFloor)}. Drivers will ignore lower offers.');
      return;
    }

    setState(() => _isBroadcasting = true);
    try {
      final provider = context.read<PassengerProvider>();

      // Build notes with tier & wait time
      final List<String> notesList = [];
      if (widget.notes != null && widget.notes!.isNotEmpty) {
        notesList.add(widget.notes!);
      }
      if (_selectedTier == 'COMFORT') notesList.add('[✨ Comfort AC Tier]');
      if (_selectedTier == 'XL_SUV') notesList.add('[🚙 XL SUV (6-seater) Tier]');
      if (_addWaitTime) {
        final waitLabel = _selectedWaitMinutes >= 60 ? '${_selectedWaitMinutes ~/ 60}hr' : '$_selectedWaitMinutes mins';
        notesList.add('[⏱️ Includes $waitLabel Stopover Wait]');
      }
      final combinedNotes =
          notesList.isNotEmpty ? notesList.join(' • ') : null;

      await provider.submitRideRequest(
        pickupLat: widget.pickupLat,
        pickupLng: widget.pickupLng,
        pickupAddress: widget.pickupAddress,
        dropoffLat: widget.dropoffLat,
        dropoffLng: widget.dropoffLng,
        dropoffAddress: widget.dropoffAddress,
        riderOfferNgn: _offerAmount,
        notes: combinedNotes,
        isBusiness: widget.isBusiness,
        riderName: widget.riderName,
        riderPhone: widget.riderPhone,
        riderType: widget.riderType,
        distanceKm: widget.distanceKm,
        durationMinutes: widget.durationMins,
        hasWaitTime: _addWaitTime,
        requestedWaitMinutes: _addWaitTime ? _selectedWaitMinutes : 0,
      );

      if (mounted) {
        Navigator.pop(context); // close sheet
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfferRoomScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBroadcasting = false);
        _showSnack(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppConstants.dangerColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppConstants.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppConstants.surfaceBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Your Fare Offer',
                  style: TextStyle(
                    color: AppConstants.textLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppConstants.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Route summary strip
          _RouteStrip(
            pickup: widget.pickupAddress,
            dropoff: widget.dropoffAddress,
            distanceKm: widget.distanceKm,
            durationMins: widget.durationMins,
          ),

          const SizedBox(height: 4),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _isLoading
                  ? const _LoadingEstimate()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ── System Estimate Box ─────────────────────
                        _SystemEstimateBox(
                          recommendedFare: _tierAmount(_selectedTier),
                          minimumFloor: _minimumFloor,
                          currencyFormat: currencyFormat,
                        ),

                        const SizedBox(height: 20),

                        // ── Vehicle Tier Cards ──────────────────────
                        const Text(
                          'CHOOSE YOUR VEHICLE',
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _TierCard(
                              id: 'ECONOMY',
                              label: 'Economy',
                              icon: Icons.directions_car_rounded,
                              price: _tierAmount('ECONOMY'),
                              isSelected: _selectedTier == 'ECONOMY',
                              onTap: () => _selectTier('ECONOMY'),
                              currencyFormat: currencyFormat,
                            ),
                            const SizedBox(width: 8),
                            _TierCard(
                              id: 'COMFORT',
                              label: 'Comfort AC',
                              icon: Icons.airline_seat_recline_extra_rounded,
                              price: _tierAmount('COMFORT'),
                              isSelected: _selectedTier == 'COMFORT',
                              onTap: () => _selectTier('COMFORT'),
                              currencyFormat: currencyFormat,
                            ),
                            const SizedBox(width: 8),
                            _TierCard(
                              id: 'XL_SUV',
                              label: 'XL SUV',
                              icon: Icons.airport_shuttle_rounded,
                              price: _tierAmount('XL_SUV'),
                              isSelected: _selectedTier == 'XL_SUV',
                              onTap: () => _selectTier('XL_SUV'),
                              currencyFormat: currencyFormat,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Your Offer Stepper ──────────────────────
                        const Text(
                          'YOUR OFFER',
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _OfferStepper(
                          offerAmount: _offerAmount,
                          minimumFloor: _minimumFloor,
                          recommendedAmount: _tierAmount(_selectedTier),
                          currencyFormat: currencyFormat,
                          onStep: _step,
                          onStartLongPress: _startLongPress,
                          onStopLongPress: _stopLongPress,
                          onManualChange: (val) {
                            setState(() => _offerAmount = val);
                          },
                        ),

                        const SizedBox(height: 8),

                        // Below-floor warning
                        if (_offerAmount < _minimumFloor)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppConstants.dangerColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppConstants.dangerColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppConstants.dangerColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Below minimum floor of ${currencyFormat.format(_minimumFloor)} — drivers are unlikely to accept.',
                                    style: const TextStyle(
                                        color: AppConstants.dangerColor,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // ── Stopover / Round-Trip Wait Time Option ──
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppConstants.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _addWaitTime ? AppConstants.accentColor.withOpacity(0.6) : Colors.white12,
                              width: _addWaitTime ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _addWaitTime ? AppConstants.accentColor.withOpacity(0.15) : AppConstants.surfaceBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.hourglass_bottom_rounded,
                                      color: _addWaitTime ? AppConstants.accentColor : AppConstants.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Need Driver to Wait at Stop?',
                                          style: TextStyle(
                                            color: AppConstants.textLight,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Round-trip, meeting or quick stopover',
                                          style: TextStyle(
                                            color: AppConstants.textMuted.withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _addWaitTime,
                                    activeColor: AppConstants.accentColor,
                                    onChanged: (val) {
                                      setState(() => _addWaitTime = val);
                                    },
                                  ),
                                ],
                              ),
                              if (_addWaitTime) ...[
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 12),
                                const Text(
                                  'EXPECTED STOP DURATION',
                                  style: TextStyle(
                                    color: AppConstants.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildWaitChip(15, '15 mins'),
                                    _buildWaitChip(30, '30 mins'),
                                    _buildWaitChip(45, '45 mins'),
                                    _buildWaitChip(60, '1 Hour'),
                                    _buildWaitChip(90, '1.5 Hours'),
                                    _buildWaitChip(120, '2 Hours'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppConstants.surfaceBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: AppConstants.accentColor, size: 14),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'First 5 mins free at stop. Metered at ₦40/min thereafter on actual duration.',
                                          style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Broadcast CTA ───────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isBroadcasting ? null : _broadcastOffer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppConstants.primaryColor.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              shadowColor:
                                  AppConstants.primaryColor.withOpacity(0.5),
                            ),
                            child: _isBroadcasting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.wifi_tethering_rounded,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Broadcast ${currencyFormat.format(_offerAmount)} to Drivers',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitChip(int mins, String label) {
    final isSel = _selectedWaitMinutes == mins;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedWaitMinutes = mins);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppConstants.accentColor : AppConstants.surfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? AppConstants.accentColor : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.black : Colors.white70,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _RouteStrip extends StatelessWidget {
  final String pickup;
  final String dropoff;
  final double distanceKm;
  final int durationMins;

  const _RouteStrip({
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.durationMins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route dot-line-dot
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppConstants.primaryLight,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                  width: 2, height: 20, color: AppConstants.primaryLight.withOpacity(0.3)),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppConstants.accentColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shortenAddress(pickup),
                  style: const TextStyle(
                      color: AppConstants.textLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _shortenAddress(dropoff),
                  style: const TextStyle(
                      color: AppConstants.accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                    color: AppConstants.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '~$durationMins min',
                style: const TextStyle(
                    color: AppConstants.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortenAddress(String addr) {
    if (addr.length <= 38) return addr;
    return '${addr.substring(0, 36)}…';
  }
}

class _SystemEstimateBox extends StatelessWidget {
  final int recommendedFare;
  final int minimumFloor;
  final NumberFormat currencyFormat;

  const _SystemEstimateBox({
    required this.recommendedFare,
    required this.minimumFloor,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryColor.withOpacity(0.18),
            AppConstants.primaryLight.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYSTEM ESTIMATE',
                  style: TextStyle(
                    color: AppConstants.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currencyFormat.format(recommendedFare),
                  style: const TextStyle(
                    color: AppConstants.textLight,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Min floor: ${currencyFormat.format(minimumFloor)}',
                  style: const TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.calculate_rounded,
              color: AppConstants.primaryLight, size: 36),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final int price;
  final bool isSelected;
  final VoidCallback onTap;
  final NumberFormat currencyFormat;

  const _TierCard({
    required this.id,
    required this.label,
    required this.icon,
    required this.price,
    required this.isSelected,
    required this.onTap,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primaryColor
                : AppConstants.surfaceBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppConstants.primaryLight
                  : Colors.white.withOpacity(0.06),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppConstants.primaryColor.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: isSelected ? Colors.white : AppConstants.textMuted,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : AppConstants.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                currencyFormat.format(price),
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppConstants.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferStepper extends StatefulWidget {
  final int offerAmount;
  final int minimumFloor;
  final int recommendedAmount;
  final NumberFormat currencyFormat;
  final void Function(int delta) onStep;
  final void Function(int delta) onStartLongPress;
  final VoidCallback onStopLongPress;
  final void Function(int val) onManualChange;

  const _OfferStepper({
    required this.offerAmount,
    required this.minimumFloor,
    required this.recommendedAmount,
    required this.currencyFormat,
    required this.onStep,
    required this.onStartLongPress,
    required this.onStopLongPress,
    required this.onManualChange,
  });

  @override
  State<_OfferStepper> createState() => _OfferStepperState();
}

class _OfferStepperState extends State<_OfferStepper> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.offerAmount.toString());
  }

  @override
  void didUpdateWidget(_OfferStepper old) {
    super.didUpdateWidget(old);
    if (!_editing && old.offerAmount != widget.offerAmount) {
      _ctrl.text = widget.offerAmount.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atFloor = widget.offerAmount <= widget.minimumFloor;
    final atCeil = widget.offerAmount >= 200000;

    return Column(
      children: [
        Row(
          children: [
            // MINUS button
            _StepButton(
              icon: Icons.remove_rounded,
              color: atFloor
                  ? AppConstants.textMuted
                  : AppConstants.dangerColor,
              onTap: atFloor ? null : () => widget.onStep(-100),
              onLongPressStart: atFloor
                  ? null
                  : () => widget.onStartLongPress(-100),
              onLongPressEnd: widget.onStopLongPress,
            ),
            const SizedBox(width: 12),

            // Amount display / edit
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppConstants.darkBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppConstants.primaryLight.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _editing
                      ? TextField(
                          controller: _ctrl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppConstants.textLight,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            prefixText: '₦ ',
                            prefixStyle: TextStyle(
                                color: AppConstants.primaryLight,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          onSubmitted: (v) {
                            final parsed =
                                int.tryParse(v.replaceAll(',', '').trim());
                            if (parsed != null) widget.onManualChange(parsed);
                            setState(() => _editing = false);
                          },
                          onTapOutside: (_) {
                            final parsed = int.tryParse(
                                _ctrl.text.replaceAll(',', '').trim());
                            if (parsed != null) widget.onManualChange(parsed);
                            setState(() => _editing = false);
                          },
                        )
                      : RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: '₦ ',
                                style: TextStyle(
                                    color: AppConstants.primaryLight,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: widget.currencyFormat
                                    .format(widget.offerAmount)
                                    .replaceAll('₦', '')
                                    .trim(),
                                style: const TextStyle(
                                    color: AppConstants.textLight,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // PLUS button
            _StepButton(
              icon: Icons.add_rounded,
              color: atCeil
                  ? AppConstants.textMuted
                  : AppConstants.successColor,
              onTap: atCeil ? null : () => widget.onStep(100),
              onLongPressStart:
                  atCeil ? null : () => widget.onStartLongPress(100),
              onLongPressEnd: widget.onStopLongPress,
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Tap hint
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_rounded,
                size: 12, color: AppConstants.textMuted),
            const SizedBox(width: 4),
            Text(
              'Each tap = ₦100  •  Hold = ₦500/sec  •  Tap amount to type',
              style: const TextStyle(
                  color: AppConstants.textMuted, fontSize: 11),
            ),
          ],
        ),

        // Vs recommended
        if (widget.offerAmount != widget.recommendedAmount) ...[
          const SizedBox(height: 6),
          Text(
            widget.offerAmount > widget.recommendedAmount
                ? '₦${widget.offerAmount - widget.recommendedAmount} above recommended — drivers will accept faster'
                : '₦${widget.recommendedAmount - widget.offerAmount} below recommended',
            style: TextStyle(
              color: widget.offerAmount >= widget.recommendedAmount
                  ? AppConstants.successColor
                  : AppConstants.accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback onLongPressEnd;

  const _StepButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart != null
          ? (_) => onLongPressStart!()
          : null,
      onLongPressEnd: (_) => onLongPressEnd(),
      onLongPressCancel: onLongPressEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppConstants.surfaceBg
              : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: onTap == null
                  ? Colors.transparent
                  : color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _LoadingEstimate extends StatelessWidget {
  const _LoadingEstimate();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          CircularProgressIndicator(
              color: AppConstants.primaryLight, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Calculating fare for your route…',
            style: TextStyle(color: AppConstants.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
