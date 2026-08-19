import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_widgets.dart';
import '../../core/supabase/auth_service.dart';
import 'connection_data.dart';
import 'connection_repository.dart';
import 'safety_repository.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({
    this.reportedUserId,
    this.reportedUserName,
    super.key,
  });

  final String? reportedUserId;
  final String? reportedUserName;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _repository = const SafetyRepository();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedType;
  XFile? _screenshot;
  bool _submitting = false;

  String? _selectedUserId;

  List<_ConnectionOption> _connections = const [];
  bool _loadingConnections = true;

  static const _types = <String>[
    'Sexual harassment',
    'Fake identity / impersonation',
    'Spam or scam',
    'Abusive behavior',
    'Inappropriate content',
    'Hate or discrimination',
    'Unwanted messages',
    'Suspicious activity',
    'Safety concern',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.reportedUserId;
    _loadConnections();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingConnections = false);
      return;
    }

    try {
      final repo = const ConnectionRepository();
      final result = await repo.getMyConnections();
      if (!mounted) return;

      final accepted = result.isSuccess
          ? result.value!.where((c) => c.status == ConnectionStatus.accepted).toList()
          : <Connection>[];

      if (accepted.isEmpty) {
        if (mounted) setState(() => _loadingConnections = false);
        return;
      }

      final otherIds = accepted
          .map((c) => c.otherUserId(user.id))
          .toList(growable: false);

      final profilesResult = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', otherIds);

      final nameMap = <String, String>{};
      for (final row in profilesResult) {
        final id = row['id'] as String;
        final name = (row['display_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          nameMap[id] = name;
        }
      }

      final options = <_ConnectionOption>[];
      for (final c in accepted) {
        final otherId = c.otherUserId(user.id);
        options.add(_ConnectionOption(
          userId: otherId,
          userName: nameMap[otherId] ?? 'Unknown',
        ));
      }

      setState(() {
        _connections = options;
        _loadingConnections = false;
        if (_selectedUserId == null && options.isNotEmpty) {
          _selectedUserId = options.first.userId;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingConnections = false);
    }
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _screenshot = picked);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to select image')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user to report')),
      );
      return;
    }
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a report type')),
      );
      return;
    }

    setState(() => _submitting = true);

    final result = await _repository.submitReport(
      reportedUserId: _selectedUserId!,
      reportType: _selectedType!,
      description: _descriptionController.text,
      screenshot: _screenshot,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted successfully. Our team will review it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to submit report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Report a Problem',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Who are you reporting?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEAEEF9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_loadingConnections)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                        )
                      else if (_connections.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                          child: Text(
                            'Open a profile to report a specific user.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: const Color(0xFFB9C3DC),
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedUserId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: .04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: .08),
                              ),
                            ),
                          ),
                          items: _connections
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.userId,
                                  child: Text(c.userName),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedUserId = v;
                            });
                          },
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'What is the issue?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEAEEF9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._types.map(
                        (type) => _ReportTypeChip(
                          label: type,
                          selected: _selectedType == type,
                          onTap: () => setState(() => _selectedType = type),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Description (optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEAEEF9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 5,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Tell us what happened...',
                          hintStyle: TextStyle(
                            color: const Color(0xFFB9C3DC).withValues(alpha: .7),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: .04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Screenshot (optional)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEAEEF9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_screenshot != null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(_screenshot!.path),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton.filled(
                                onPressed: () => setState(() => _screenshot = null),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: .6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton.icon(
                        onPressed: _pickScreenshot,
                        icon: Icon(
                          _screenshot == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.swap_horiz_rounded,
                        ),
                        label: Text(_screenshot == null
                            ? 'Add Screenshot'
                            : 'Change Screenshot'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEAEEF9),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ConexoButton(
                        label: 'Submit Report',
                        onPressed: _submitting ? null : _submit,
                        isLoading: _submitting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTypeChip extends StatelessWidget {
  const _ReportTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6).withValues(alpha: .18)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5CF6)
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: selected ? const Color(0xFF8B5CF6) : const Color(0xFFB9C3DC),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFFEAEEF9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionOption {
  const _ConnectionOption({
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;
}
