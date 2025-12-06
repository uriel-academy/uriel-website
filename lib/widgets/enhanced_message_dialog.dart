import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EnhancedMessageDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final String recipientRole; // 'student' or 'teacher'
  final List<String>? availableClasses;
  final bool enableMultiSelect;

  const EnhancedMessageDialog({
    Key? key,
    required this.allUsers,
    required this.recipientRole,
    this.availableClasses,
    this.enableMultiSelect = true,
  }) : super(key: key);

  @override
  State<EnhancedMessageDialog> createState() => _EnhancedMessageDialogState();
}

class _EnhancedMessageDialogState extends State<EnhancedMessageDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  String _recipientType = 'all';
  String? _selectedClass;
  Set<String> _selectedUserIds = {};
  bool _isSending = false;
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    return widget.allUsers.where((user) {
      final name = (user['displayName'] ?? user['teacherName'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _paginatedUsers {
    final start = _currentPage * _itemsPerPage;
    final end = start + _itemsPerPage;
    return _filteredUsers.sublist(
      start,
      end > _filteredUsers.length ? _filteredUsers.length : end,
    );
  }

  int get _totalPages => (_filteredUsers.length / _itemsPerPage).ceil();

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    // Validation
    if (title.isEmpty) {
      _showError('Please enter a title');
      return;
    }
    if (message.isEmpty) {
      _showError('Please enter a message');
      return;
    }
    if (_recipientType == 'class' && _selectedClass == null) {
      _showError('Please select a class');
      return;
    }
    if (_recipientType == 'individual' && _selectedUserIds.isEmpty) {
      _showError('Please select at least one recipient');
      return;
    }
    if (_recipientType == 'multiple' && _selectedUserIds.isEmpty) {
      _showError('Please select at least one recipient');
      return;
    }

    setState(() => _isSending = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('sendMessage');

      final data = <String, dynamic>{
        'title': title,
        'message': message,
        'recipientType': _recipientType,
      };

      if (_recipientType == 'individual') {
        data['recipientId'] = _selectedUserIds.first;
      } else if (_recipientType == 'multiple') {
        data['recipientIds'] = _selectedUserIds.toList();
      } else if (_recipientType == 'class') {
        data['grade'] = _selectedClass;
      }

      final result = await callable.call(data);
      final response = result.data as Map<String, dynamic>;
      final recipientCount = response['recipientCount'] ?? 0;

      if (!mounted) return;
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Message sent to $recipientCount ${widget.recipientRole}${recipientCount == 1 ? '' : 's'}',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF00C853),
        ),
      );
    } catch (e) {
      setState(() => _isSending = false);
      if (!mounted) return;
      _showError('Error sending message: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMultipleMode = _recipientType == 'multiple';
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: const BoxDecoration(
                color: Color(0xFF001F3F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send Message',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (isMultipleMode && _selectedUserIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedUserIds.length} selected',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipient Type Selector
                    Text(
                      'Send To',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1d1d1f),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTypeChip('all', 'All ${widget.recipientRole}s', Icons.people),
                        if (widget.availableClasses != null)
                          _buildTypeChip('class', 'Specific Class', Icons.group),
                        _buildTypeChip('individual', 'Single ${widget.recipientRole}', Icons.person),
                        if (widget.enableMultiSelect)
                          _buildTypeChip('multiple', 'Select Multiple', Icons.checklist),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Class Picker
                    if (_recipientType == 'class' && widget.availableClasses != null) ...[
                      _buildDropdown(
                        label: 'Select Class',
                        value: _selectedClass,
                        items: widget.availableClasses!,
                        onChanged: (value) => setState(() => _selectedClass = value),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // User Selector
                    if (_recipientType == 'individual' || _recipientType == 'multiple') ...[
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() => _currentPage = 0),
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF001F3F), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // User List
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: _filteredUsers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    'No ${widget.recipientRole}s found',
                                    style: GoogleFonts.inter(color: Colors.grey[600]),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _paginatedUsers.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                                      itemBuilder: (context, index) {
                                        final user = _paginatedUsers[index];
                                        final userId = user['uid'] ?? user['teacherId'] as String;
                                        final name = user['displayName'] ?? user['teacherName'] ?? 'Unknown';
                                        final email = user['email'] ?? '';
                                        final isSelected = _selectedUserIds.contains(userId);

                                        return Material(
                                          color: isSelected ? const Color(0xFF001F3F).withOpacity(0.05) : Colors.white,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (isMultipleMode) {
                                                  if (isSelected) {
                                                    _selectedUserIds.remove(userId);
                                                  } else {
                                                    _selectedUserIds.add(userId);
                                                  }
                                                } else {
                                                  _selectedUserIds = {userId};
                                                }
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                children: [
                                                  if (isMultipleMode)
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      margin: const EdgeInsets.only(right: 12),
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? const Color(0xFF00C853) : Colors.white,
                                                        border: Border.all(
                                                          color: isSelected ? const Color(0xFF00C853) : Colors.grey[400]!,
                                                          width: 2,
                                                        ),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: isSelected
                                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                          : null,
                                                    )
                                                  else if (isSelected)
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      margin: const EdgeInsets.only(right: 12),
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF00C853),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                                                    ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xFF1d1d1f),
                                                          ),
                                                        ),
                                                        Text(
                                                          email,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Pagination
                                  if (_totalPages > 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        border: Border(top: BorderSide(color: Colors.grey[300]!)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chevron_left),
                                            onPressed: _currentPage > 0
                                                ? () => setState(() => _currentPage--)
                                                : null,
                                            iconSize: 20,
                                          ),
                                          Text(
                                            'Page ${_currentPage + 1} of $_totalPages',
                                            style: GoogleFonts.inter(fontSize: 13),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right),
                                            onPressed: _currentPage < _totalPages - 1
                                                ? () => setState(() => _currentPage++)
                                                : null,
                                            iconSize: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Title Field
                    _buildTextField(
                      label: 'Title',
                      controller: _titleController,
                      maxLength: 200,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 20),

                    // Message Field
                    _buildTextField(
                      label: 'Message',
                      controller: _messageController,
                      maxLength: 2000,
                      maxLines: 6,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSending ? 'Sending...' : 'Send Message',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _recipientType == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _recipientType = value;
          _selectedUserIds.clear();
          _currentPage = 0;
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF001F3F),
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1d1d1f),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: 'Choose...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF001F3F), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: GoogleFonts.inter(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required int maxLength,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1d1d1f),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1d1d1f)),
          decoration: InputDecoration(
            hintText: 'Enter $label...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF001F3F), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
          ),
          maxLength: maxLength,
          maxLines: maxLines,
        ),
      ],
    );
  }
}
