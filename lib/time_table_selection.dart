import 'package:darzo/admin/time_table.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimetableSelectionPage extends StatefulWidget {
  final bool isAdmin;
  const TimetableSelectionPage({super.key, required this.isAdmin});

  @override
  State<TimetableSelectionPage> createState() => _TimetableSelectionPageState();
}

class _TimetableSelectionPageState extends State<TimetableSelectionPage> {
  final Color primaryBlue = const Color(0xFF2196F3);

  // Selections
  String? selectedDeptId;
  String? selectedClassId;
  String? selectedSemester;

  // Data Stores
  Map<String, String> departments = {}; // {id: name}
  List<Map<String, dynamic>> allClasses = []; // Full list
  List<Map<String, dynamic>> filteredClasses = []; // Filtered by Dept
  List<String> availableSemesters = []; // Filtered by Class logic

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Fetch Departments (Collection: 'department')
      final deptSnap = await firestore.collection('department').get();
      for (var doc in deptSnap.docs) {
        final data = doc.data();
        departments[doc.id] = data['name'] ?? data['deptName'] ?? doc.id;
      }

      // 2. Fetch All Classes (Collection: 'class')
      final classSnap = await firestore.collection('class').get();
      for (var doc in classSnap.docs) {
        final data = doc.data();
        allClasses.add({
          'id': doc.id,
          'name': data['name'] ?? data['className'] ?? doc.id,
          'departmentId': data['departmentId'] ?? '',
        });
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 1. Filter Classes based on Department
  void _onDeptChanged(String? deptId) {
    setState(() {
      selectedDeptId = deptId;
      selectedClassId = null;
      selectedSemester = null;
      availableSemesters = []; // Reset semesters

      if (deptId != null) {
        final targetId = deptId.trim().toUpperCase();

        filteredClasses = allClasses.where((c) {
          final String cDeptId = c['departmentId']
              .toString()
              .trim()
              .toUpperCase();
          final String cId = c['id'].toString().trim().toUpperCase();
          // Match if departmentId field matches OR Class ID starts with Dept ID
          return cDeptId == targetId || cId.startsWith(targetId);
        }).toList();
      } else {
        filteredClasses = [];
      }
    });
  }

  // 2. Filter Semesters based on Class Name/ID
  void _onClassChanged(String? classId) {
    setState(() {
      selectedClassId = classId;
      selectedSemester = null;

      if (classId != null) {
        // Find the class object to check its name/id for patterns
        // We use the ID string (e.g. "COMPUTER_SCIENCE_PG_YEAR1") for logic
        String idUpper = classId.toUpperCase();

        availableSemesters = _getSemestersForClass(idUpper);
      } else {
        availableSemesters = [];
      }
    });
  }

  // LOGIC: Define Semesters based on UG/PG and Year
  List<String> _getSemestersForClass(String id) {
    if (id.contains("PG")) {
      if (id.contains("YEAR1") || id.contains("YEAR_1"))
        return ["Semester 1", "Semester 2"];
      if (id.contains("YEAR2") || id.contains("YEAR_2"))
        return ["Semester 3", "Semester 4"];
    } else if (id.contains("UG")) {
      if (id.contains("YEAR1") || id.contains("YEAR_1"))
        return ["Semester 1", "Semester 2"];
      if (id.contains("YEAR2") || id.contains("YEAR_2"))
        return ["Semester 3", "Semester 4"];
      if (id.contains("YEAR3") || id.contains("YEAR_3"))
        return ["Semester 5", "Semester 6"];
    }

    // Fallback: If pattern not found, show all 8
    return List.generate(8, (i) => "Semester ${i + 1}");
  }

  void _navigateToEditor() {
    if (selectedDeptId == null ||
        selectedClassId == null ||
        selectedSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Department, Class, and Semester"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Generate ID: CLASS_SEM (e.g., "BCOM_UG_YEAR3_SEMESTER5")
    final String docId =
        "${selectedClassId}_${selectedSemester!.replaceAll(' ', '')}"
            .toUpperCase()
            .replaceAll(' ', '');

    final deptName = departments[selectedDeptId];
    final className = filteredClasses.firstWhere(
      (c) => c['id'] == selectedClassId,
    )['name'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditableTimetablePage(
          timetableId: docId,
          title: "$deptName • $className",
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: const Text("Select Timetable"),
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSelectionCard(),
                  const SizedBox(height: 30),
                  _buildContinueButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.calendar_month_rounded, size: 60, color: primaryBlue),
        const SizedBox(height: 16),
        const Text(
          "Configure Schedule",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Select the details below to view or edit the timetable.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Department
          _sectionLabel("Department"),
          _buildDropdown(
            hint: "Select Department",
            value: selectedDeptId,
            items: departments.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: _onDeptChanged,
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 20),

          // 2. Class (Filtered)
          _sectionLabel("Class"),
          _buildDropdown(
            hint: selectedDeptId == null
                ? "Select Department First"
                : (filteredClasses.isEmpty
                      ? "No Classes Found"
                      : "Select Class"),
            value: selectedClassId,
            items: filteredClasses
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text(c['name']),
                  ),
                )
                .toList(),
            onChanged: _onClassChanged, // Calls semester logic
            icon: Icons.class_outlined,
            isDisabled: selectedDeptId == null || filteredClasses.isEmpty,
          ),
          const SizedBox(height: 20),

          // 3. Semester (Logic Filtered)
          _sectionLabel("Semester"),
          _buildDropdown(
            hint: selectedClassId == null
                ? "Select Class First"
                : "Select Semester",
            value: selectedSemester,
            items: availableSemesters
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() => selectedSemester = val),
            icon: Icons.timeline,
            isDisabled: selectedClassId == null,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>>? items,
    required Function(String?) onChanged,
    required IconData icon,
    bool isDisabled = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey[100] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDisabled ? Colors.grey : primaryBlue),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        hint: Text(hint, style: TextStyle(color: Colors.grey[500])),
        items: items,
        onChanged: isDisabled ? null : onChanged,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        style: TextStyle(
          color: isDisabled ? Colors.grey : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _navigateToEditor,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryBlue.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "Continue to Timetable",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
