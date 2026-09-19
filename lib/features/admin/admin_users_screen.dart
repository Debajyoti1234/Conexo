import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_data_service.dart';
import 'models/admin_overview_data.dart';
import 'models/admin_user.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminDataService _dataService = const AdminDataService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _search = '';
  String _verification = '';
  String _visibility = '';
  String _sort = 'newest';
  int _limit = 25;
  int _offset = 0;
  int? _total;

  Timer? _debounce;
  Future<AdminUserListPage>? _pageFuture;

  @override
  void initState() {
    super.initState();
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

  Future<AdminUserListPage> _fetchPage() async {
    try {
      return await _dataService.fetchUsers(
        limit: _limit,
        offset: _offset,
        search: _search,
        verificationStatus: _verification,
        profileVisibility: _visibility,
        sort: _sort,
      );
    } on AdminDataException {
      rethrow;
    } catch (_) {
      throw const AdminDataException(
        'Unable to load users. Please try again.',
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

  void _onVerificationChanged(String? value) {
    _verification = value ?? '';
    _applyQuery();
  }

  void _onVisibilityChanged(String? value) {
    _visibility = value ?? '';
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

  void _retry() => _applyQuery();

  void _clearAll() {
    _searchCtrl.clear();
    _search = '';
    _verification = '';
    _visibility = '';
    _sort = 'newest';
    _applyQuery();
  }

  void _onRowTap(AdminUser user) {
    Navigator.of(context).push(
      AppRouter.slideRoute(AdminUserDetailScreen(userId: user.userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkTheme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(total: _total),
          const SizedBox(height: 16),
          _UsersToolbar(
            searchCtrl: _searchCtrl,
            searchValue: _search,
            onSearchChanged: _onSearchChanged,
            verificationValue: _verification,
            onVerificationChanged: _onVerificationChanged,
            visibilityValue: _visibility,
            onVisibilityChanged: _onVisibilityChanged,
            sortValue: _sort,
            onSortChanged: _onSortChanged,
            onRefresh: _retry,
            onClear: _clearAll,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<AdminUserListPage>(
              future: _pageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _UsersLoadingState();
                }
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: _retry);
                }
                final users = snapshot.data?.users ?? const <AdminUser>[];
                if (users.isEmpty) {
                  return const _EmptyState();
                }
                final page = snapshot.data!;
                return Column(
                  children: [
                    Expanded(
                      child: _UsersTable(
                        users: users,
                        onRowTap: _onRowTap,
                      ),
                    ),
                    _PaginationFooter(
                      offset: _offset,
                      limit: _limit,
                      total: page.total,
                      visibleCount: users.length,
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
              'Users',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Manage and inspect Conexo user accounts',
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
              ? '— users'
              : '$total ${total == 1 ? 'user' : 'users'}',
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

class _UsersToolbar extends StatelessWidget {
  const _UsersToolbar({
    required this.searchCtrl,
    required this.searchValue,
    required this.onSearchChanged,
    required this.verificationValue,
    required this.onVerificationChanged,
    required this.visibilityValue,
    required this.onVisibilityChanged,
    required this.sortValue,
    required this.onSortChanged,
    required this.onRefresh,
    required this.onClear,
  });

  final TextEditingController searchCtrl;
  final String searchValue;
  final ValueChanged<String> onSearchChanged;
  final String verificationValue;
  final ValueChanged<String?> onVerificationChanged;
  final String visibilityValue;
  final ValueChanged<String?> onVisibilityChanged;
  final String sortValue;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  static const _verificationOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: '', child: Text('All')),
    DropdownMenuItem(value: 'verified', child: Text('Verified')),
    DropdownMenuItem(value: 'pending', child: Text('Pending')),
    DropdownMenuItem(value: 'notVerified', child: Text('Not Verified')),
  ];

  static const _visibilityOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: '', child: Text('All')),
    DropdownMenuItem(value: 'public', child: Text('Public')),
    DropdownMenuItem(value: 'private', child: Text('Private')),
  ];

  static const _sortOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'newest', child: Text('Newest')),
    DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
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
          value: verificationValue,
          items: _verificationOptions,
          onChanged: onVerificationChanged,
        ),
        _StyledDropdown<String>(
          width: 140,
          value: visibilityValue,
          items: _visibilityOptions,
          onChanged: onVisibilityChanged,
        ),
        _StyledDropdown<String>(
          width: 170,
          value: sortValue,
          items: _sortOptions,
          onChanged: onSortChanged,
        ),
        const SizedBox(width: 4),
        _IconButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          onPressed: onRefresh,
        ),
        _IconButton(
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

class _IconButton extends StatelessWidget {
  const _IconButton({
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

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.onRowTap,
  });

  final List<AdminUser> users;
  final ValueChanged<AdminUser> onRowTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29324A)),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          horizontalMargin: 16,
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
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
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Verification')),
            DataColumn(label: Text('Visibility')),
            DataColumn(label: Text('Completion')),
            DataColumn(label: Text('Activity')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Connections')),
            DataColumn(label: Text('Reports')),
            DataColumn(label: Text('Registered')),
          ],
          rows: [
            for (final user in users)
              DataRow(
                onSelectChanged: (_) => onRowTap(user),
                cells: <DataCell>[
                  DataCell(_UserCell(user: user)),
                  DataCell(_cell(user.email)),
                  DataCell(_StatusCell(
                    label: _verificationLabel(user),
                    dotColor: _verificationDotColor(user),
                  )),
                  DataCell(_StatusCell(
                    label: _visibilityLabel(user),
                    dotColor: _visibilityDotColor(user),
                  )),
                  DataCell(_StatusCell(
                    label: user.profileCompleted
                        ? 'Completed'
                        : 'Incomplete',
                    dotColor: user.profileCompleted
                        ? const Color(0xFF22C58E)
                        : const Color(0xFF4B5563),
                  )),
                  DataCell(_cell(_timeAgo(user.lastActiveAt))),
                  DataCell(_cell(_locationStatusText(user))),
                  DataCell(_cell('${user.connectionCount}')),
                  DataCell(_cell('${user.reportCount}')),
                  DataCell(_cell(_formatDate(user.registrationDate))),
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
      );
}

class _UserCell extends StatelessWidget {
  const _UserCell({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName;
    final display = (name == null || name.isEmpty) ? 'Unnamed user' : name;
    final idFragment = user.userId.isNotEmpty
        ? user.userId.substring(0, user.userId.length >= 8 ? 8 : user.userId.length)
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
              style: const TextStyle(
                color: Color(0xFF8E98B8),
                fontSize: 11,
              ),
            ),
          ],
        );
      },
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

class _UsersLoadingState extends StatelessWidget {
  const _UsersLoadingState();

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
                  for (int i = 0; i < 10; i++)
                    Container(
                      width: i == 0 ? 180 : i == 1 ? 200 : 90,
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
            'No users found',
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
              'Unable to load users',
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
        color: enabled
            ? const Color(0xFFD0D7F4)
            : const Color(0xFF4B5563),
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

String _locationStatusText(AdminUser user) {
  final status = user.locationStatus;
  final updatedAt = user.locationUpdatedAt;
  switch (status) {
    case 'live':
      return 'Live · ${_timeAgo(updatedAt)}';
    case 'stale':
      return 'Stale · ${_timeAgo(updatedAt)}';
    default:
      return '—';
  }
}

String _verificationLabel(AdminUser user) {
  switch (user.verificationStatus) {
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

Color? _verificationDotColor(AdminUser user) {
  switch (user.verificationStatus) {
    case 'verified':
      return const Color(0xFF22C58E);
    case 'pending':
      return const Color(0xFFF59E0B);
    default:
      return null;
  }
}

String _visibilityLabel(AdminUser user) {
  switch (user.profileVisibility) {
    case 'public':
      return 'Public';
    case 'private':
      return 'Private';
    default:
      return '—';
  }
}

Color? _visibilityDotColor(AdminUser user) {
  switch (user.profileVisibility) {
    case 'public':
      return const Color(0xFF3B82F6);
    case 'private':
      return const Color(0xFF6B7280);
    default:
      return null;
  }
}
