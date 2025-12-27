import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddInternalMarksBulkPage extends StatefulWidget {
  const AddInternalMarksBulkPage({super.key});

  @override
  State<AddInternalMarksBulkPage> createState() =>
      _AddInternalMarksBulkPageState();
}

class _AddInternalMarksBulkPageState extends State<AddInternalMarksBulkPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Selections ---
  String? _selectedDept;
  String? _selectedClass;

  // --- Data Sources (Mocked for Demo structure) ---
  // In a real app, these might be fetched from Firestore beforehand.
  final List<String> _departments = ['CSE', 'ECE', 'MECH'];
  final Map<String, List<String>> _classesByDept = {
    'CSE': ['Year 1', 'Year 2', 'Year 3'],
    'ECE': ['Year 1', 'Year 2'],
    'MECH': ['Year 1', 'Year 2', 'Year 3', 'Year 4'],
  };

  // Ideally, subjects are fetched based on dept/class selection.
  // Hardcoded here for simplicity.
  final List<String> _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Core',
  ];

  // --- State Variables ---
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _students = [];

  // The core state controller: Maps Student ID -> { Subject Name -> Controller }
  final Map<String, Map<String, TextEditingController>> _markControllers = {};

  @override
  void dispose() {
    // Clean up all controllers
    for (var studentMap in _markControllers.values) {
      for (var controller in studentMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  // --- Logic ---

  void _onDeptChanged(String? newValue) {
    setState(() {
      _selectedDept = newValue;
      _selectedClass = null; // Reset class when dept changes
      _resetData();
    });
  }

  void _onClassChanged(String? newValue) {
    setState(() {
      _selectedClass = newValue;
      _resetData();
    });
    if (_selectedClass != null && _selectedDept != null) {
      _fetchStudentsAndExistingMarks();
    }
  }

  void _resetData() {
    _students = [];
    _markControllers.forEach((key, value) {
      value.forEach((subKey, controller) => controller.dispose());
    });
    _markControllers.clear();
  }

  Future<void> _fetchStudentsAndExistingMarks() async {
    setState(() => _isLoading = true);
    _resetData();

    try {
      // 1. Fetch Students matching criteria
      final studentSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('department', isEqualTo: _selectedDept)
          .where('classYear', isEqualTo: _selectedClass)
          .get();

      _students = studentSnap.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unknown',
          // store other needed details
        };
      }).toList();

      if (_students.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Define the context ID for marks storage
      final String contextId = '${_selectedDept}_$_selectedClass';

      // 3. Fetch ALL existing marks for this context in one go
      // Path: internal_marks/CSE_Year 1/student_marks/
      final existingMarksSnap = await _firestore
          .collection('internal_marks')
          .doc(contextId)
          .collection('student_marks')
          .get();

      // Create a lookup map for existing marks: StudentID -> {Subject: Mark}
      Map<String, Map<String, dynamic>> existingMarksLookup = {};
      for (var doc in existingMarksSnap.docs) {
        existingMarksLookup[doc.id] = doc.data();
      }

      // 4. Initialize Controllers and Pre-fill data
      for (var student in _students) {
        String studentId = student['id'];
        _markControllers[studentId] = {};

        // Get existing marks for this specific student (if any)
        Map<String, dynamic> studentExistingMarks =
            existingMarksLookup[studentId] ?? {};

        for (var subject in _subjects) {
          // Check if a mark exists for this subject
          String initialValue = '';
          if (studentExistingMarks.containsKey(subject)) {
            initialValue = studentExistingMarks[subject].toString();
          }

          _markControllers[studentId]![subject] = TextEditingController(
            text: initialValue,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBulkMarks() async {
    if (_selectedDept == null || _selectedClass == null) return;
    setState(() => _isSaving = true);

    final String contextId = '${_selectedDept}_$_selectedClass';
    final WriteBatch batch = _firestore.batch();

    int updateCount = 0;

    try {
      // Iterate through the controllers to build the batch write
      for (var student in _students) {
        String studentId = student['id'];
        Map<String, dynamic> marksToSave = {};
        bool hasData = false;

        _markControllers[studentId]?.forEach((subject, controller) {
          String text = controller.text.trim();
          if (text.isNotEmpty) {
            // Try parse, default to 0 or null if invalid depending on needs
            int? mark = int.tryParse(text);
            if (mark != null) {
              marksToSave[subject] = mark;
              hasData = true;
            }
          }
        });

        if (hasData) {
          DocumentReference studentMarkRef = _firestore
              .collection('internal_marks')
              .doc(contextId)
              .collection('student_marks')
              .doc(studentId);

          // CRITICAL: Use SetOptions(merge: true).
          // This ensures we update existing subjects or add new ones,
          // without wiping out other subjects not currently present in the _subjects list.
          batch.set(studentMarkRef, marksToSave, SetOptions(merge: true));
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully saved marks for $updateCount students.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No marks to save.')));
        }
      }
    } catch (e) {
      debugPrint('Error saving bulk marks: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Internal Marks (Bulk)')),
      body: Column(
        children: [
          _buildSelectionArea(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                ? const Center(
                    child: Text(
                      'Select department and class to load students.',
                    ),
                  )
                : _buildStudentList(),
          ),
        ],
      ),
      bottomNavigationBar: _students.isNotEmpty ? _buildSaveButton() : null,
    );
  }

  Widget _buildSelectionArea() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Department Dropdown
            DropdownButtonFormField<String>(
              value: _selectedDept,
              decoration: const InputDecoration(
                labelText: 'Select Department',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _departments
                  .map(
                    (dept) => DropdownMenuItem(value: dept, child: Text(dept)),
                  )
                  .toList(),
              onChanged: _isLoading ? null : _onDeptChanged,
            ),
            const SizedBox(height: 16),
            // Class Dropdown (Dependent on Dept)
            DropdownButtonFormField<String>(
              value: _selectedClass,
              decoration: const InputDecoration(
                labelText: 'Select Class',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: (_selectedDept == null)
                  ? []
                  : _classesByDept[_selectedDept]!
                        .map(
                          (cl) => DropdownMenuItem(value: cl, child: Text(cl)),
                        )
                        .toList(),
              onChanged: (_selectedDept == null || _isLoading)
                  ? null
                  : _onClassChanged,
              hint: Text(
                _selectedDept == null
                    ? 'Select Department first'
                    : 'Select Class',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _students.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final student = _students[index];
        final String studentId = student['id'];

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Header
                Text(
                  student['name'],
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'ID: $studentId',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(),

                // Subject Mark Inputs Grid
                // Using Wrap instead of GridView for dynamic height inside ListView
                Wrap(
                  spacing: 16.0,
                  runSpacing: 12.0,
                  children: _subjects.map((subject) {
                    // Ensure controller exists before trying to access it
                    final controller = _markControllers[studentId]?[subject];
                    if (controller == null) return const SizedBox.shrink();

                    return SizedBox(
                      width: 100, // Fixed width for each mark input
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: subject,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveBulkMarks,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('SAVE ALL MARKS', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
