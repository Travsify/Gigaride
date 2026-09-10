import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

enum TimeFilter { today, week, month, year, custom }

class DriverRidesScreen extends StatefulWidget {
  const DriverRidesScreen({super.key});

  @override
  State<DriverRidesScreen> createState() => _DriverRidesScreenState();
}

class _DriverRidesScreenState extends State<DriverRidesScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _allRides = [];
  TimeFilter _selectedFilter = TimeFilter.today;
  DateTime? _selectedCustomDate;

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    setState(() => _isLoading = true);
    try {
      final rides = await _api.getDriverRideHistory();
      if (mounted) {
        setState(() {
          _allRides = rides;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredRides {
    final now = DateTime.now();
    return _allRides.where((ride) {
      final createdAtStr = ride['created_at'] ?? ride['createdAt'];
      if (createdAtStr == null) return false;
      final date = DateTime.tryParse(createdAtStr);
      if (date == null) return false;

      switch (_selectedFilter) {
        case TimeFilter.today:
          // Past 24 hours / calendar today
          return date.year == now.year && date.month == now.month && date.day == now.day;
        case TimeFilter.week:
          // Last 7 days
          return now.difference(date).inDays <= 7;
        case TimeFilter.month:
          // Current month
          return date.year == now.year && date.month == now.month;
        case TimeFilter.year:
          // Current year
          return date.year == now.year;
        case TimeFilter.custom:
          if (_selectedCustomDate == null) return true;
          return date.year == _selectedCustomDate!.year &&
              date.month == _selectedCustomDate!.month &&
              date.day == _selectedCustomDate!.day;
      }
    }).toList();
  }

  int get _totalCompletedRides {
    return _filteredRides.where((r) => r['status'] == 'COMPLETED').length;
  }

  int get _totalEarningsNgn {
    int total = 0;
    for (final r in _filteredRides) {
      if (r['status'] == 'COMPLETED') {
        final fare = r['agreed_fare_ngn'] ?? r['rider_offer_ngn'] ?? r['suggested_fare_ngn'] ?? 0;
        if (fare is num) {
          total += fare.toInt();
        }
      }
    }
    return total;
  }

  String _formatNgn(int amount) {
    return NumberFormat('#,##0').format(amount);
  }

  Future<void> _selectCustomDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? DateTime.now(),
      firstDate: DateTime(2025, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              surface: AppConstants.cardBg,
              onSurface: AppConstants.textLight,
            ),
            dialogBackgroundColor: AppConstants.cardBg,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedCustomDate = picked;
        _selectedFilter = TimeFilter.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRides;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.history_edu_rounded, color: AppConstants.primaryLight, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ride & Trip Analytics',
                          style: TextStyle(color: AppConstants.textLight, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Track trips, earnings & breakdown over time',
                          style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppConstants.textMuted),
                    onPressed: _fetchRides,
                  ),
                ],
              ),
            ),

            // Time Horizon Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('Today (24h)', TimeFilter.today),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Week', TimeFilter.week),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Month', TimeFilter.month),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Year', TimeFilter.year),
                  const SizedBox(width: 8),
                  ActionChip(
                    backgroundColor: _selectedFilter == TimeFilter.custom ? AppConstants.primaryColor : AppConstants.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: _selectedFilter == TimeFilter.custom ? AppConstants.primaryLight : Colors.white12),
                    avatar: const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
                    label: Text(
                      _selectedFilter == TimeFilter.custom && _selectedCustomDate != null
                          ? DateFormat('dd MMM yyyy').format(_selectedCustomDate!)
                          : 'Select Date',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _selectCustomDate(context),
                  ),
                ],
              ),
            ),

            // Metric Overview Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D3728), Color(0xFF072118)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_car_rounded, color: AppConstants.primaryLight, size: 18),
                              SizedBox(width: 6),
                              Text('TOTAL TRIPS', style: TextStyle(color: AppConstants.primaryLight, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalCompletedRides',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${filtered.length} requests handled',
                            style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2C2407), Color(0xFF191404)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppConstants.accentColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.payments_rounded, color: AppConstants.accentColor, size: 18),
                              SizedBox(width: 6),
                              Text('EARNINGS', style: TextStyle(color: AppConstants.accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₦${_formatNgn(_totalEarningsNgn)}',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '100% kept • 0% Cut',
                            style: TextStyle(color: AppConstants.successColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Rides List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trip Details (${filtered.length})',
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (_selectedFilter == TimeFilter.custom)
                    TextButton(
                      onPressed: () => setState(() => _selectedFilter = TimeFilter.today),
                      child: const Text('Reset to Today', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12)),
                    ),
                ],
              ),
            ),

            // Trip Cards List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.commute_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                              const SizedBox(height: 12),
                              const Text('No rides found for this period', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('Go online on Radar to accept new passenger requests', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final ride = filtered[i];
                            final status = (ride['status'] ?? 'COMPLETED').toString();
                            final isCompleted = status == 'COMPLETED';
                            final fare = ride['agreed_fare_ngn'] ?? ride['rider_offer_ngn'] ?? ride['suggested_fare_ngn'] ?? 0;
                            final dateStr = ride['created_at'] ?? ride['createdAt'];
                            final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
                            final formattedDate = date != null ? DateFormat('dd MMM • hh:mm a').format(date) : 'Recent';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppConstants.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
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
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isCompleted ? AppConstants.successColor.withOpacity(0.15) : AppConstants.dangerColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: isCompleted ? AppConstants.successColor : AppConstants.dangerColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(formattedDate, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                        ],
                                      ),
                                      Text(
                                        '₦${_formatNgn(fare is num ? fare.toInt() : 0)}',
                                        style: const TextStyle(color: AppConstants.accentColor, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.trip_origin_rounded, color: AppConstants.primaryLight, size: 14),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ride['pickup_address'] ?? ride['pickupAddress'] ?? 'Pickup point',
                                          style: const TextStyle(color: AppConstants.textLight, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: AppConstants.dangerColor, size: 14),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ride['dropoff_address'] ?? ride['dropoffAddress'] ?? 'Dropoff destination',
                                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, TimeFilter filter) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppConstants.textLight, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppConstants.primaryColor,
      backgroundColor: AppConstants.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(color: isSelected ? AppConstants.primaryLight : Colors.white12),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = filter;
            _selectedCustomDate = null;
          });
        }
      },
    );
  }
}
