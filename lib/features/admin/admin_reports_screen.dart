import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_data_service.dart';
import 'admin_report_detail_screen.dart';
import 'models/admin_overview_data.dart';
import 'models/admin_report.dart';
import '../../app/router/app_router.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final AdminDataService _dataService = const AdminDataService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _search = '';
  String _statusFilter = '';
  String _sort = 'newest';
  int _limit = 25;
  int _offset = 0;
  int? _total;

  Timer? _debounce;
  late Future<AdminReportPage> _pageFuture;
  late Future<AdminReportSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _pageFuture = _fetchPage().then((page) {
      _total = page.total;
      return page;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadSummary() {
    _summaryFuture = _dataService.fetchReportSummary();
  }

  Future<AdminReportPage> _fetchPage() async {
    try {
      return await _dataService.fetchReports(
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
        'Unable to load reports. Please try again.',
      );
    }
  }

  void _applyQuery({bool resetPage = true}) {
    setState(() {
      if (resetPage) _offset = 0;
      _pageFuture = _fetchPage().then((page) {
        _total = page.total;
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
    _sort = value ?? 'newest';
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
        _total = page.total;
        return page;
      });
    });
  }

  void _nextPage() {
    setState(() {
      _offset += _limit;
      _pageFuture = _fetchPage().then((page) {
        _total = page.total;
        return page;
      });
    });
  }

  void _retry() {
    setState(() {
      _loadSummary();
      _pageFuture = _fetchPage().then((page) {
        _total = page.total;
        return page;
      });
    });
  }

  void _clearAll() {
    _searchCtrl.clear();
    _search = '';
    _statusFilter = '';
    _sort = 'newest';
    _applyQuery();
  }

  Future<void> _onView(AdminReport report) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRouter.slideRoute(
        AdminReportDetailScreen(reportId: report.reportId),
      ),
    );
    if (changed == true && mounted) {
      _loadSummary();
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
          _ReportsToolbar(
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
            child: FutureBuilder<AdminReportPage>(
              future: _pageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingState();
                }
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: _retry);
                }
                final reports = snapshot.data?.reports ?? const <AdminReport>[];
                if (reports.isEmpty) {
                  return const _EmptyState();
                }
                final page = snapshot.data!;
                return Column(
                  children: [
                    Expanded(
                      child: _ReportsTable(
                        reports: reports,
                        onView: _onView,
                      ),
                    ),
                    _PaginationFooter(
                      offset: _offset,
                      limit: _limit,
                      total: page.total,
                      visibleCount: reports.length,
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
    return FutureBuilder<AdminReportSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _skeletonCards();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _summaryCards(
            0, 0, 0, 0, 0,
          );
        }
        final summary = snapshot.data!;
        return _summaryCards(
          summary.pending,
          summary.reviewing,
          summary.resolved,
          summary.dismissed,
          summary.actionTaken,
        );
      },
    );
  }

  Widget _skeletonCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 180).floor().clamp(1, 5);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            crossAxisCount,
            (index) => SizedBox(
              width: (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount,
              child: const _SkeletonCard(),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCards(
    int pending,
    int reviewing,
    int resolved,
    int dismissed,
    int actionTaken,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const count = 5;
        final crossAxisCount = (constraints.maxWidth / 180).floor().clamp(1, count);
        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _SummaryCard(
              width: cardWidth,
              icon: Icons.pending_actions_outlined,
              iconColor: const Color(0xFFF59E0B),
              label: 'Pending',
              value: '$pending',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.visibility_outlined,
              iconColor: const Color(0xFF3B82F6),
              label: 'Reviewing',
              value: '$reviewing',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF22C58E),
              label: 'Resolved',
              value: '$resolved',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.dismiss_small_rounded,
              iconColor: const Color(0xFF6B7280),
              label: 'Dismissed',
              value: '$dismissed',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.gavel_rounded,
              iconColor: const Color(0xFF8B5CF6),
              label: 'Action Taken',
              value: '$actionTaken',
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
              'Reports',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Review user-submitted safety reports and moderation status.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF7E88A8),
              ),
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
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                icon,
                size: 21,
                color: iconColor,
              ),
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

class _ReportsToolbar extends StatelessWidget {
  const _ReportsToolbar({
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
    DropdownMenuItem(value: '', child: Text('All Statuses')),
    DropdownMenuItem(value: 'pending', child: Text('Pending')),
    DropdownMenuItem(value: 'reviewing', child: Text('Reviewing')),
    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
    DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
    DropdownMenuItem(value: 'action_taken', child: Text('Action Taken')),
  ];

  static const _sortOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'newest', child: Text('Newest')),
    DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
    DropdownMenuItem(value: 'updated_newest', child: Text('Recently Updated')),
    DropdownMenuItem(value: 'updated_oldest', child: Text('Oldest Updated')),
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
              hintText: 'Search by reporter, reported, type, or ID',
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
          width: 170,
          value: statusFilterValue,
          items: _statusFilterOptions,
          onChanged: onStatusFilterChanged,
        ),
        _StyledDropdown<String>(
          width: 180,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _ReportsTable extends StatelessWidget {
  const _ReportsTable({
    required this.reports,
    required this.onView,
  });

  final List<AdminReport> reports;
  final ValueChanged<AdminReport> onView;

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
          headingTextStyle:
              const TextStyle(color: Color(0xFF8E98B8), fontSize: 12),
          dataTextStyle:
              const TextStyle(color: Colors.white, fontSize: 13),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.selected)) {
              return const Color(0xFF1F2A48);
            }
            return null;
          }),
          columns: const <DataColumn>[
            DataColumn(label: Text('Report')),
            DataColumn(label: Text('Reporter')),
            DataColumn(label: Text('Reported User')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('Updated')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final report in reports)
              DataRow(
                cells: <DataCell>[
                  DataCell(_idCell(report.reportId)),
                  DataCell(_cell(report.reporterNameSnapshot ?? '—')),
                  DataCell(_cell(report.reportedNameSnapshot ?? '—')),
                  DataCell(_cell(report.reportType)),
                  DataCell(_StatusCell(
                    label: _reportStatusLabel(report.status),
                    dotColor: _reportStatusColor(report.status),
                  )),
                  DataCell(_cell(_formatDate(report.createdAt))),
                  DataCell(_cell(_timeAgo(report.updatedAt))),
                  DataCell(
                    TextButton(
                      onPressed: () => onView(report),
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
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Widget _cell(String? value) => Text(
        value ?? '—',
        style: const TextStyle(color: Color(0xFFD0D7F4)),
        overflow: TextOverflow.ellipsis,
      );

  static Widget _idCell(String id) {
    final display = id.length >= 8 ? id.substring(0, 8) : id;
    return Text(
      display,
      style: const TextStyle(
        color: Color(0xFFD0D7F4),
        fontFamily: 'RobotoMono',
        fontSize: 13,
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.label,
    required this.dotColor,
  });

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
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 20,
                children: [
                  for (int i = 0; i < 8; i++)
                    Container(
                      width: i == 0
                          ? 80
                          : i == 1
                              ? 140
                              : i == 2
                                  ? 140
                                  : i == 3
                                      ? 120
                                      : 100,
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
          Icon(
            Icons.search_off_outlined,
            size: 48,
            color: Color(0xFF7E88A8),
          ),
          SizedBox(height: 16),
          Text(
            'No reports found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9AA3C2),
            ),
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
              'Unable to load reports',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            '$start–$end of $totalStr',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9AA3C2),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _timeAgo(DateTime? date) {
  if (date == null) return '—';
  final now = DateTime.now();
  final elapsed = now.difference(date);
  if (elapsed.isNegative) return 'now';
  if (elapsed.inSeconds < 5) return 'now';
  if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s ago';
  if (elapsed.inMinutes < 60) {
    final minutes = elapsed.inMinutes;
    return '$minutes min${minutes == 1 ? '' : 's'} ago';
  }
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays == 1) return 'Yesterday';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return _formatDate(date);
}

String _reportStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'reviewing':
      return 'Reviewing';
    case 'resolved':
      return 'Resolved';
    case 'dismissed':
      return 'Dismissed';
    case 'action_taken':
      return 'Action Taken';
    default:
      return '—';
  }
}

Color? _reportStatusColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFF59E0B);
    case 'reviewing':
      return const Color(0xFF3B82F6);
    case 'resolved':
      return const Color(0xFF22C58E);
    case 'dismissed':
      return const Color(0xFF6B7280);
    case 'action_taken':
      return const Color(0xFF8B5CF6);
    default:
      return null;
  }
}