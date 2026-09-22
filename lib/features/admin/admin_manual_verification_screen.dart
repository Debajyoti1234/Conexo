import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_data_service.dart';
import 'models/admin_manual_verification_entry.dart';
import 'models/admin_overview_data.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';

class AdminManualVerificationScreen extends StatefulWidget {
  const AdminManualVerificationScreen({super.key});

  @override
  State<AdminManualVerificationScreen> createState() =>
      _AdminManualVerificationScreenState();
}

class _AdminManualVerificationScreenState
    extends State<AdminManualVerificationScreen> {
  final AdminDataService _dataService = const AdminDataService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _search = '';
  String _statusFilter = '';
  String _sort = 'pending_first';
  int _limit = 25;
  int _offset = 0;
  int? _total;

  Timer? _debounce;
  late Future<AdminManualVerificationPage> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = _fetchPage().then((page) {
      if (!mounted) return page;
      setState(() => _total = page.total);
      return page;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<AdminManualVerificationPage> _fetchPage() async {
    try {
      return await _dataService.fetchManualVerifications(
        limit: _limit,
        offset: _offset,
        search: _search,
        status: _statusFilter,
        sort: _sort,
      );
    } on AdminDataException {
      rethrow;
    } catch (_) {
      throw const AdminDataException(
        'Unable to load manual verification queue. Please try again.',
      );
    }
  }

  void _applyQuery({bool resetPage = true}) {
    setState(() {
      if (resetPage) _offset = 0;
      _pageFuture = _fetchPage().then((page) {
        if (!mounted) return page;
        setState(() => _total = page.total);
        return page;
      });
    });
  }

  void _onSearchChanged(String value) {
    _search = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _applyQuery);
  }

  void _onStatusFilterChanged(String? value) {
    _statusFilter = value ?? '';
    _applyQuery();
  }

  void _onSortChanged(String? value) {
    _sort = value ?? 'pending_first';
    _applyQuery();
  }

  void _onLimitChanged(int? value) {
    _limit = value ?? 25;
    _applyQuery();
  }

  void _previousPage() {
    setState(() {
      _offset = (_offset - _limit).clamp(0, 1 << 30);
      _pageFuture = _fetchPage().then((page) {
        if (!mounted) return page;
        setState(() => _total = page.total);
        return page;
      });
    });
  }

  void _nextPage() {
    setState(() {
      _offset += _limit;
      _pageFuture = _fetchPage().then((page) {
        if (!mounted) return page;
        setState(() => _total = page.total);
        return page;
      });
    });
  }

  void _retry() {
    setState(() {
      _pageFuture = _fetchPage().then((page) {
        if (!mounted) return page;
        setState(() => _total = page.total);
        return page;
      });
    });
  }

  void _clearAll() {
    _searchCtrl.clear();
    _search = '';
    _statusFilter = '';
    _sort = 'pending_first';
    _applyQuery();
  }

  Future<void> _onView(String requestId) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRouter.slideRoute(
        AdminManualVerificationDetailScreen(requestId: requestId),
      ),
    );
    if (changed == true && mounted) {
      _retry();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1020),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(total: _total),
          const SizedBox(height: 20),
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _VerificationToolbar(
            searchCtrl: _searchCtrl,
            searchValue: _search,
            onSearchChanged: _onSearchChanged,
            statusFilterValue: _statusFilter,
            onStatusFilterChanged: _onStatusFilterChanged,
            sortValue: _sort,
            onSortChanged: _onSortChanged,
            onRefresh: _retry,
            onClear: _clearAll,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<AdminManualVerificationPage>(
              future: _pageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingState();
                }
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: _retry);
                }
                final entries =
                    snapshot.data?.entries ?? const <AdminManualVerificationEntry>[];
                if (entries.isEmpty) {
                  return const _EmptyState();
                }
                final page = snapshot.data!;
                return Column(
                  children: [
                    Expanded(
                      child: _VerificationTable(
                        entries: entries,
                        onView: _onView,
                      ),
                    ),
                    _PaginationFooter(
                      offset: _offset,
                      limit: _limit,
                      total: page.total,
                      visibleCount: entries.length,
                      onPrevious: _previousPage,
                      onNext: _nextPage,
                      onLimitChanged: _onLimitChanged,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return FutureBuilder<AdminManualVerificationPage>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _skeletonCards();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _summaryCards(0, 0, 0);
        }
        final entries = snapshot.data!.entries;
        final pending = entries.where((e) => e.manualStatus == 'pending_review').length;
        final approved = entries.where((e) => e.manualStatus == 'approved').length;
        final rejected = entries.where((e) => e.manualStatus == 'rejected').length;
        return _summaryCards(pending, approved, rejected);
      },
    );
  }

  Widget _skeletonCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : 1;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            crossAxisCount,
            (index) => SizedBox(
              width:
                  (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                  crossAxisCount,
              child: const _SkeletonCard(),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCards(int pending, int approved, int rejected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : 1;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _SummaryCard(
              width:
                  (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                  crossAxisCount,
              icon: Icons.pending_actions_outlined,
              iconColor: const Color(0xFFF59E0B),
              label: 'Pending Review',
              value: '$pending',
            ),
            _SummaryCard(
              width:
                  (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                  crossAxisCount,
              icon: Icons.verified_outlined,
              iconColor: const Color(0xFF22C58E),
              label: 'Approved',
              value: '$approved',
            ),
            _SummaryCard(
              width:
                  (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                  crossAxisCount,
              icon: Icons.cancel_outlined,
              iconColor: const Color(0xFFEF4444),
              label: 'Rejected',
              value: '$rejected',
            ),
          ],
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({this.total});

  final int? total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Manual Verification',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Review manual verification requests',
              style: TextStyle(fontSize: 13, color: Color(0xFF7E88A8)),
            ),
          ],
        ),
        const Spacer(),
        Text(
          total == null
              ? '— entries'
              : '$total ${total == 1 ? 'entry' : 'entries'}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8E98B8),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF151B2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF29324A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 21, color: iconColor),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E98B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationToolbar extends StatelessWidget {
  const _VerificationToolbar({
    required this.searchCtrl,
    required this.searchValue,
    required this.onSearchChanged,
    required this.statusFilterValue,
    required this.onStatusFilterChanged,
    required this.sortValue,
    required this.onSortChanged,
    required this.onRefresh,
    required this.onClear,
  });

  final TextEditingController searchCtrl;
  final String searchValue;
  final ValueChanged<String> onSearchChanged;
  final String statusFilterValue;
  final ValueChanged<String?> onStatusFilterChanged;
  final String sortValue;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  static const _statusFilterOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: '', child: Text('All')),
    DropdownMenuItem(value: 'pending_review', child: Text('Pending Review')),
    DropdownMenuItem(value: 'approved', child: Text('Approved')),
    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
  ];

  static const _sortOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'pending_first', child: Text('Pending First')),
    DropdownMenuItem(value: 'newest', child: Text('Newest')),
    DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
    DropdownMenuItem(value: 'updated_newest', child: Text('Recently Updated')),
    DropdownMenuItem(value: 'updated_oldest', child: Text('Oldest Updated')),
    DropdownMenuItem(value: 'name_asc', child: Text('Name A–Z')),
    DropdownMenuItem(value: 'name_desc', child: Text('Name Z–A')),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by name, email, or ID',
              hintStyle: const TextStyle(color: Color(0xFF7E88A8)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: Color(0xFF7E88A8),
              ),
              isDense: true,
            ),
          ),
        ),
        _StyledDropdown<String>(
          width: 160,
          value: statusFilterValue,
          items: _statusFilterOptions,
          onChanged: onStatusFilterChanged,
        ),
        _StyledDropdown<String>(
          width: 190,
          value: sortValue,
          items: _sortOptions,
          onChanged: onSortChanged,
        ),
        const SizedBox(width: 4),
        _TextIconButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          onPressed: onRefresh,
        ),
        _TextIconButton(
          icon: Icons.filter_alt_off_rounded,
          label: 'Clear',
          onPressed: onClear,
        ),
      ],
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 150,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: Color(0xFF7E88A8),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        dropdownColor: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        selectedItemBuilder: (context) => items
            .map((item) => Align(alignment: Alignment.centerLeft, child: item))
            .toList(),
      ),
    );
  }
}

class _TextIconButton extends StatelessWidget {
  const _TextIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: const Color(0xFF9AA3C2)),
      label: Text(
        label,
        style: const TextStyle(color: Color(0xFF9AA3C2), fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _VerificationTable extends StatelessWidget {
  const _VerificationTable({required this.entries, required this.onView});

  final List<AdminManualVerificationEntry> entries;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          horizontalMargin: 16,
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          showBottomBorder: true,
          headingTextStyle: const TextStyle(
            color: Color(0xFF8E98B8),
            fontSize: 12,
          ),
          dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.selected)) {
              return const Color(0xFF1F2A48);
            }
            return null;
          }),
          columns: const <DataColumn>[
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Manual Status')),
            DataColumn(label: Text('Profile Status')),
            DataColumn(label: Text('Submitted')),
            DataColumn(label: Text('Reviewed')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final entry in entries)
              DataRow(
                cells: <DataCell>[
                  DataCell(_UserCell(entry: entry)),
                  DataCell(_cell(entry.email)),
                  DataCell(
                    _StatusCell(
                      label: _manualStatusLabel(entry.manualStatus),
                      dotColor: _manualStatusDotColor(entry.manualStatus),
                    ),
                  ),
                  DataCell(
                    _StatusCell(
                      label: _profileStatusLabel(entry.verificationStatus),
                      dotColor: _profileStatusDotColor(entry.verificationStatus),
                    ),
                  ),
                  DataCell(_cell(_formatDate(entry.createdAt))),
                  DataCell(_cell(_formatDate(entry.reviewedAt))),
                  DataCell(
                    entry.manualStatus == 'pending_review'
                        ? TextButton(
                            onPressed: () => onView(entry.requestId),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: const Text(
                              'View',
                              style: TextStyle(
                                color: Color(0xFF9D82FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : _StatusCell(
                            label: _manualStatusLabel(entry.manualStatus),
                            dotColor: _manualStatusDotColor(entry.manualStatus),
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Widget _cell(String? value) =>
      Text(value ?? '—', style: const TextStyle(color: Color(0xFFD0D7F4)));
}

class _UserCell extends StatelessWidget {
  const _UserCell({required this.entry});

  final AdminManualVerificationEntry entry;

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName;
    final display = (name == null || name.isEmpty) ? 'Unnamed user' : name;
    final idFragment = entry.userId.isNotEmpty
        ? entry.userId.substring(
            0,
            entry.userId.length >= 8 ? 8 : entry.userId.length,
          )
        : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowId = constraints.maxWidth > 120;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              display,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              canShowId ? '· $idFragment' : '· ····',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8E98B8), fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.label, this.dotColor});

  final String label;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    if (dotColor == null) {
      return Text(
        label,
        style: const TextStyle(color: Color(0xFF9AA3C2), fontSize: 12),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFD0D7F4), fontSize: 12),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final shimmer = Colors.white.withValues(alpha: 0.06);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF29324A)),
          ...List.generate(
            7,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 20,
                children: [
                  for (int i = 0; i < 7; i++)
                    Container(
                      width: i == 0
                          ? 180
                          : i == 1
                          ? 160
                          : i == 2
                          ? 120
                          : i == 3
                          ? 100
                          : i == 4
                          ? 100
                          : i == 5
                          ? 100
                          : 60,
                      height: 13,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(4),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search_off_outlined, size: 48, color: Color(0xFF7E88A8)),
          SizedBox(height: 16),
          Text(
            'No manual verification entries found',
            style: TextStyle(fontSize: 16, color: Color(0xFF9AA3C2)),
          ),
          SizedBox(height: 6),
          Text(
            'The current search or filters returned no results.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF7E88A8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9D82FF).withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: Color(0xFFB7A5FF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to load manual verification queue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your connection and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7E88A8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.offset,
    required this.limit,
    required this.total,
    required this.visibleCount,
    required this.onPrevious,
    required this.onNext,
    required this.onLimitChanged,
  });

  final int offset;
  final int limit;
  final int? total;
  final int visibleCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int?> onLimitChanged;

  @override
  Widget build(BuildContext context) {
    final start = offset + 1;
    final end = offset + visibleCount;
    final totalStr = total?.toStringAsFixed(0) ?? '—';
    final canPrevious = offset > 0;
    final canNext = total != null && (offset + limit) < total!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        border: Border(top: BorderSide(color: const Color(0xFF29324A))),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            '$start–$end of $totalStr',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3C2)),
          ),
          const Spacer(),
          _StyledDropdown<int>(
            width: 110,
            value: limit,
            items: const <DropdownMenuItem<int>>[
              DropdownMenuItem(value: 25, child: Text('25 / page')),
              DropdownMenuItem(value: 50, child: Text('50 / page')),
              DropdownMenuItem(value: 100, child: Text('100 / page')),
            ],
            onChanged: onLimitChanged,
          ),
          const SizedBox(width: 8),
          _IconToggle(
            icon: Icons.navigate_before_rounded,
            label: 'Previous',
            enabled: canPrevious,
            onPressed: onPrevious,
          ),
          const SizedBox(width: 8),
          _IconToggle(
            icon: Icons.navigate_next_rounded,
            label: 'Next',
            enabled: canNext,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        icon,
        size: 16,
        color: enabled ? const Color(0xFFD0D7F4) : const Color(0xFF4B5563),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: enabled ? const Color(0xFFD0D7F4) : const Color(0xFF4B5563),
          fontSize: 12,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class AdminManualVerificationDetailScreen extends StatefulWidget {
  const AdminManualVerificationDetailScreen({
    required this.requestId,
    super.key,
  });

  final String requestId;

  @override
  State<AdminManualVerificationDetailScreen> createState() =>
      _AdminManualVerificationDetailScreenState();
}

class _AdminManualVerificationDetailScreenState
    extends State<AdminManualVerificationDetailScreen> {
  final AdminDataService _dataService = const AdminDataService();
  bool _verificationChanged = false;
  late Future<AdminManualVerificationDetail?> _detailFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _detailFuture = _fetch();
    });
  }

  Future<AdminManualVerificationDetail?> _fetch() async {
    try {
      return await _dataService.getManualVerification(widget.requestId);
    } on AdminDataException {
      rethrow;
    } catch (_) {
      throw const AdminDataException(
        'Unable to load verification request. Please try again.',
      );
    }
  }

  void _retry() => _load();

  void _onActionComplete() {
    setState(() => _verificationChanged = true);
    _load();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_verificationChanged);
    }
  }

  Future<void> _onApprove() async {
    final detail = await _detailFuture;
    if (detail == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveDialog(detail: detail),
    );
    if (confirmed != true) return;

    setState(() {});
    try {
      final result = await _dataService.approveManualVerification(
        requestId: widget.requestId,
        expectedStatus: detail.manualStatus ?? '',
      );
      if (!mounted) return;

      if (result.success) {
        _onActionComplete();
        _showSnackBar('Manual verification approved');
      } else if (result.message.startsWith('Status changed')) {
        _showConcurrencyConflict();
      } else {
        _showSnackBar(result.message);
      }
    } on AdminDataException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Unable to approve. Please try again.');
    }
  }

  Future<void> _onReject() async {
    final detail = await _detailFuture;
    if (detail == null) return;

    final reasonController = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RejectDialog(
        detail: detail,
        reasonController: reasonController,
      ),
    );
    if (confirmed != true) {
      reasonController.dispose();
      return;
    }
    final reason = reasonController.text;
    reasonController.dispose();

    setState(() {});
    try {
      final result = await _dataService.rejectManualVerification(
        requestId: widget.requestId,
        expectedStatus: detail.manualStatus ?? '',
        rejectionReason: reason,
      );
      if (!mounted) return;

      if (result.success) {
        _onActionComplete();
        _showSnackBar('Manual verification rejected');
      } else if (result.message.startsWith('Status changed')) {
        _showConcurrencyConflict();
      } else {
        _showSnackBar(result.message);
      }
    } on AdminDataException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Unable to reject. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF151B2E),
          behavior: SnackBarBehavior.floating,
          width: 320,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _showConcurrencyConflict() {
    if (!mounted) return;
    _showSnackBar(
      'This verification request was already updated by another admin. '
      'Refreshing the request.',
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _DetailTopBar(onBack: _back, onRefresh: _retry),
          const Divider(height: 1, color: Color(0xFF1E2438)),
          Expanded(
            child: FutureBuilder<AdminManualVerificationDetail?>(
              future: _detailFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _DetailLoadingState();
                }
                if (snapshot.hasError) {
                  return _DetailErrorState(
                    onRetry: _retry,
                    onBack: _back,
                  );
                }
                final detail = snapshot.data;
                if (detail == null) {
                  return _DetailNotFoundState(onBack: _back);
                }
                return _DetailBody(
                  detail: detail,
                  onActionComplete: _onActionComplete,
                  onApprove: _onApprove,
                  onReject: _onReject,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2438)),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF9AA3C2),
            ),
            label: const Text(
              'Manual Verification',
              style: TextStyle(
                color: Color(0xFFB7A5FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: Color(0xFF9AA3C2),
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatefulWidget {
  const _DetailBody({
    required this.detail,
    required this.onActionComplete,
    required this.onApprove,
    required this.onReject,
  });

  final AdminManualVerificationDetail detail;
  final VoidCallback onActionComplete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  final bool _approving = false;
  final bool _rejecting = false;

  bool get _isPending => widget.detail.manualStatus == 'pending_review';

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final narrow = MediaQuery.of(context).size.width < 900;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _IdentityHeader(detail: detail),
        const SizedBox(height: 24),
        narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._leftColumnChildren(detail),
                  ..._rightColumnChildren(detail),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _leftColumnChildren(detail),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _rightColumnChildren(detail),
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _leftColumnChildren(AdminManualVerificationDetail d) => [
        _RequestInfoCard(detail: d),
        const SizedBox(height: 16),
        _DocumentsSection(detail: d),
        const SizedBox(height: 16),
        _ActionCard(
          isPending: _isPending,
          approving: _approving,
          rejecting: _rejecting,
          onApprove: _isPending ? widget.onApprove : null,
          onReject: _isPending ? widget.onReject : null,
          manualStatus: widget.detail.manualStatus,
        ),
      ];

  List<Widget> _rightColumnChildren(AdminManualVerificationDetail d) => [
        _UserInfoCard(detail: d),
      ];
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({required this.detail});

  final AdminManualVerificationDetail detail;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'User',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: 'Display name',
            value: detail.displayName ?? '—',
          ),
          _InfoRow(
            label: 'Email',
            value: detail.email ?? '—',
          ),
          _InfoRow(
            label: 'User ID',
            value: detail.userId,
          ),
          _InfoRow(
            label: 'Profile verification',
            value: _profileStatusLabel(detail.verificationStatus),
          ),
        ],
      ),
    );
  }
}

class _RequestInfoCard extends StatelessWidget {
  const _RequestInfoCard({required this.detail});

  final AdminManualVerificationDetail detail;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Request',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: 'Request ID',
            value: detail.requestId,
          ),
          _InfoRow(
            label: 'Submitted',
            value: _formatDateTime(detail.createdAt),
          ),
          _InfoRow(
            label: 'Manual status',
            value: _manualStatusLabel(detail.manualStatus),
          ),
          _InfoRow(
            label: 'Reviewed at',
            value: _formatDateTime(detail.reviewedAt),
          ),
          _InfoRow(
            label: 'Reviewed by',
            value: detail.reviewedBy ?? '—',
          ),
          if (detail.rejectionReason != null &&
              detail.rejectionReason!.isNotEmpty)
            _InfoRow(
              label: 'Rejection reason',
              value: detail.rejectionReason!,
            ),
        ],
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.detail});

  final AdminManualVerificationDetail detail;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DocumentPreview(
            path: detail.selfiePath ?? '',
            title: 'Selfie',
          ),
          const SizedBox(height: 16),
          _DocumentPreview(
            path: detail.idFrontPath ?? '',
            title: 'ID Front',
          ),
          if (detail.idBackPath != null && detail.idBackPath!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DocumentPreview(
              path: detail.idBackPath!,
              title: 'ID Back',
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.isPending,
    required this.approving,
    required this.rejecting,
    required this.onApprove,
    required this.onReject,
    required this.manualStatus,
  });

  final bool isPending;
  final bool approving;
  final bool rejecting;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final String? manualStatus;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPending) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: approving ? null : onApprove,
                    icon: approving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_rounded, size: 18),
                    label: Text(
                      approving ? 'Approving...' : 'Approve',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C58E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: rejecting ? null : onReject,
                    icon: rejecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cancel_rounded, size: 18),
                    label: Text(
                      rejecting ? 'Rejecting...' : 'Reject',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'This request has already been reviewed. Actions are no longer available.',
              style: TextStyle(
                fontSize: 12,
                color: _manualStatusDotColor(manualStatus) ??
                    const Color(0xFF7E88A8),
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatefulWidget {
  const _DocumentPreview({required this.path, required this.title});

  final String path;
  final String title;

  @override
  State<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<_DocumentPreview> {
  String? _signedUrl;
  bool _urlLoading = true;
  bool _urlError = false;

  @override
  void initState() {
    super.initState();
    _generateSignedUrl();
  }

  Future<void> _generateSignedUrl() async {
    try {
      final url = await Supabase.instance.client.storage
          .from('verification-documents')
          .createSignedUrl(widget.path, 600);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _urlLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _urlLoading = false;
          _urlError = true;
        });
      }
    }
  }

  void _retryUrl() {
    setState(() {
      _signedUrl = null;
      _urlError = false;
      _urlLoading = true;
    });
    _generateSignedUrl();
  }

  void _retryImage() {
    _generateSignedUrl();
  }

  @override
  Widget build(BuildContext context) {
    if (_urlLoading) {
      return _DocLoadingPlaceholder(title: widget.title);
    }
    if (_urlError) {
      return _DocFailed(
        title: widget.title,
        message: 'Failed to generate preview link',
        onRetry: _retryUrl,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8E98B8),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _signedUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return _DocLoadingPlaceholder(title: widget.title);
            },
            errorBuilder: (_, _, _) => _DocFailed(
              title: widget.title,
              message: 'Failed to load image',
              onRetry: _retryImage,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _signedUrl = null;
    super.dispose();
  }
}

class _DocLoadingPlaceholder extends StatelessWidget {
  const _DocLoadingPlaceholder({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading $title...',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7E88A8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocFailed extends StatelessWidget {
  const _DocFailed({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                size: 32, color: Color(0xFF4B5563)),
            const SizedBox(height: 8),
            Text(
              '$title: $message',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7E88A8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApproveDialog extends StatelessWidget {
  const _ApproveDialog({required this.detail});

  final AdminManualVerificationDetail detail;

  String get _name {
    final name = detail.displayName;
    return (name == null || name.isEmpty) ? 'Unnamed user' : name;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF151B2E),
      surfaceTintColor: const Color(0xFF151B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: const Text(
        'Approve Verification',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD0D7F4),
            ),
          ),
          const SizedBox(height: 12),
          _dialogRow('Request ID', detail.requestId),
          _dialogRow('Current status', _manualStatusLabel(detail.manualStatus)),
          _dialogRow('New status', 'Approved'),
          const SizedBox(height: 8),
          const Text(
            'This will approve the manual verification and mark the user as verified. '
            'This action is auditable and cannot be undone from the Admin console.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF7E88A8),
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF9AA3C2)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C58E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({
    required this.detail,
    required this.reasonController,
  });

  final AdminManualVerificationDetail detail;
  final TextEditingController reasonController;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  String? _validationError;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF151B2E),
      surfaceTintColor: const Color(0xFF151B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: const Text(
        'Reject Verification',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.detail.displayName ?? 'Unnamed user',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD0D7F4),
            ),
          ),
          const SizedBox(height: 12),
          _dialogRow('Request ID', widget.detail.requestId),
          _dialogRow('Current status', _manualStatusLabel(widget.detail.manualStatus)),
          _dialogRow('New status', 'Rejected'),
          const SizedBox(height: 8),
          TextField(
            controller: widget.reasonController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Rejection reason (optional)',
              hintStyle: const TextStyle(color: Color(0xFF7E88A8)),
              errorText: _validationError,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF29324A)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The user will be marked as Not Verified. '
            'This action is auditable and cannot be undone from the Admin console.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF7E88A8),
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.reasonController.dispose();
            Navigator.of(context).pop(false);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF9AA3C2)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _validationError = null;
            });
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.detail});

  final AdminManualVerificationDetail detail;

  @override
  Widget build(BuildContext context) {
    final name = detail.displayName;
    final display = (name == null || name.isEmpty) ? 'Unnamed user' : name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail.userId,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E98B8),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: _manualStatusLabel(detail.manualStatus),
              dotColor: _manualStatusDotColor(detail.manualStatus),
            ),
            _StatusChip(
              label: _profileStatusLabel(detail.verificationStatus),
              dotColor: _profileStatusDotColor(detail.verificationStatus),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8E98B8),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7E88A8),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFD0D7F4),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.dotColor});

  final String label;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD0D7F4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState();

  @override
  Widget build(BuildContext context) {
    final shimmer = Colors.white.withValues(alpha: 0.06);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 240,
                    height: 24,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    height: 14,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  for (int i = 0; i < 6; i++) ...[
                    _DetailSkeleton(),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        _DetailSkeleton(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        _DetailSkeleton(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({
    required this.onRetry,
    required this.onBack,
  });

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9D82FF).withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: Color(0xFFB7A5FF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to load verification request',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your connection and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7E88A8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: Color(0xFF9AA3C2),
              ),
              label: const Text(
                'Back to Queue',
                style: TextStyle(color: Color(0xFFB7A5FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailNotFoundState extends StatelessWidget {
  const _DetailNotFoundState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 48,
            color: Color(0xFF7E88A8),
          ),
          const SizedBox(height: 16),
          const Text(
            'Verification request not found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9AA3C2),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF9AA3C2),
            ),
            label: const Text(
              'Back to Queue',
              style: TextStyle(color: Color(0xFFB7A5FF)),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _dialogRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF7E88A8), fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFFD0D7F4), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

String _formatDateTime(DateTime? date) {
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _manualStatusLabel(String? status) {
  switch (status) {
    case 'pending_review':
      return 'Pending Review';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    default:
      return '—';
  }
}

Color? _manualStatusDotColor(String? status) {
  switch (status) {
    case 'pending_review':
      return const Color(0xFFF59E0B);
    case 'approved':
      return const Color(0xFF22C58E);
    case 'rejected':
      return const Color(0xFFEF4444);
    default:
      return null;
  }
}

String _profileStatusLabel(String? status) {
  switch (status) {
    case 'verified':
      return 'Verified';
    case 'pending':
      return 'Pending';
    case 'notVerified':
      return 'Not Verified';
    default:
      return '—';
  }
}

Color? _profileStatusDotColor(String? status) {
  switch (status) {
    case 'verified':
      return const Color(0xFF22C58E);
    case 'pending':
      return const Color(0xFFF59E0B);
    default:
      return null;
  }
}
