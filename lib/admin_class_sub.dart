import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminClassSubjectPage extends StatefulWidget {
  const AdminClassSubjectPage({super.key});

  @override
  State<AdminClassSubjectPage> createState() => _AdminClassSubjectPageState();
}

class _AdminClassSubjectPageState extends State<AdminClassSubjectPage> {
  String? departmentId;
  String? classId;

  String? courseType;
  int? year;
  int? semester;

  final classCtrl = TextEditingController();
  final subjectCtrl = TextEditingController();

  List<int> allowedSemesters() {
    if (courseType == null || year == null) return [];

    if (courseType == 'UG') {
      if (year == 1) return [1, 2];
      if (year == 2) return [3, 4];
      if (year == 3) return [5, 6];
    }

    if (courseType == 'PG') {
      if (year == 1) return [1, 2];
      if (year == 2) return [3, 4];
    }

    return [];
  }

  Future<void> addClass() async {
    if (departmentId == null ||
        classCtrl.text.isEmpty ||
        courseType == null ||
        year == null)
      return;

    await FirebaseFirestore.instance.collection('classes').add({
      'name': classCtrl.text.trim(),
      'departmentId': departmentId,
      'courseType': courseType,
      'year': year,
      'created_at': FieldValue.serverTimestamp(),
    });

    classCtrl.clear();
  }

  Future<void> addSubject() async {
    if (classId == null || semester == null || subjectCtrl.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('subjects').add({
      'name': subjectCtrl.text.trim(),
      'classId': classId,
      'departmentId': departmentId,
      'semester': semester,
      'created_at': FieldValue.serverTimestamp(),
    });

    subjectCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Classes & Subjects")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// ---------------- DEPARTMENT ----------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('departments')
                .orderBy('name')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();

              return DropdownButtonFormField<String>(
                value: departmentId,
                hint: const Text("Select Department"),
                items: snap.data!.docs
                    .map(
                      (d) =>
                          DropdownMenuItem(value: d.id, child: Text(d['name'])),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    departmentId = v;
                    classId = null;
                  });
                },
              );
            },
          ),

          const SizedBox(height: 24),

          /// ---------------- ADD CLASS ----------------
          const Text(
            "Add Class",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: classCtrl,
            decoration: const InputDecoration(labelText: "Class Name"),
          ),

          DropdownButtonFormField<String>(
            value: courseType,
            hint: const Text("Course Type"),
            items: const [
              DropdownMenuItem(value: 'UG', child: Text("UG")),
              DropdownMenuItem(value: 'PG', child: Text("PG")),
            ],
            onChanged: (v) => setState(() {
              courseType = v;
              year = null;
            }),
          ),

          DropdownButtonFormField<int>(
            value: year,
            hint: const Text("Year"),
            items: (courseType == 'UG' ? [1, 2, 3] : [1, 2])
                .map((y) => DropdownMenuItem(value: y, child: Text("Year $y")))
                .toList(),
            onChanged: (v) => setState(() => year = v),
          ),

          ElevatedButton(onPressed: addClass, child: const Text("Add Class")),

          const Divider(height: 40),

          /// ---------------- EXISTING CLASSES ----------------
          if (departmentId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .where('departmentId', isEqualTo: departmentId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snap.data!.docs.map((doc) {
                    return ListTile(
                      title: Text(doc['name']),
                      subtitle: Text(
                        "${doc['courseType']} • Year ${doc['year']}",
                      ),
                      onTap: () {
                        setState(() {
                          classId = doc.id;
                          courseType = doc['courseType'];
                          year = doc['year'];
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),

          const Divider(height: 40),

          /// ---------------- ADD SUBJECT ----------------
          if (classId != null) ...[
            const Text(
              "Add Subject",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(labelText: "Subject Name"),
            ),

            DropdownButtonFormField<int>(
              value: semester,
              hint: const Text("Semester"),
              items: allowedSemesters()
                  .map((s) => DropdownMenuItem(value: s, child: Text("Sem $s")))
                  .toList(),
              onChanged: (v) => setState(() => semester = v),
            ),

            ElevatedButton(
              onPressed: addSubject,
              child: const Text("Add Subject"),
            ),
          ],

          const SizedBox(height: 20),

          /// ---------------- EXISTING SUBJECTS ----------------
          if (classId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subjects')
                  .where('classId', isEqualTo: classId)
                  .orderBy('semester')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();

                final grouped = <int, List<QueryDocumentSnapshot>>{};
                for (var d in snap.data!.docs) {
                  grouped.putIfAbsent(d['semester'], () => []).add(d);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: grouped.entries.map((e) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Semester ${e.key}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...e.value.map((s) => ListTile(title: Text(s['name']))),
                        const Divider(),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
