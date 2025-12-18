// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:darzo/ZIP/login.dart';
// import 'package:darzo/teacher/internal_mark.dart';
// import 'package:darzo/teacher/teacher_students.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:darzo/ZIP/attendance.dart';

// // TEACHER DASHBOARD PAGE
// class TeacherDashboardPage extends StatefulWidget {
//   const TeacherDashboardPage({super.key});

//   @override
//   State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
// }

// class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
//   final ScrollController _scrollController = ScrollController();

//   // TEACHER DATA STATE
//   String teacherName = "Loading...";
//   String departmentName = "Loading...";

//   // REMINDER DATA
//   final List<Map<String, String>> reminders = [
//     {"title": "Conduct Internal Exam ", "subtitle": "Next Monday"},
//     {"title": "Record Correction", "subtitle": "This Friday"},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _fetchTeacherData();
//   }

//   // 🔥 FETCH TEACHER PROFILE
//   Future<void> _fetchTeacherData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final doc = await FirebaseFirestore.instance
//             .collection('teachers')
//             .doc(user.uid)
//             .get();

//         if (doc.exists && mounted) {
//           final data = doc.data()!;
//           setState(() {
//             teacherName = data['name'] ?? "Teacher";
//             departmentName = data['departmentName'] ?? "Unknown Dept";
//           });
//         }
//       } catch (e) {
//         debugPrint("Error fetching teacher data: $e");
//       }
//     }
//   }

//   // MAIN BUILD
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF2196F3),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () async {
//             await FirebaseAuth.instance.signOut();
//             if (context.mounted) {
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (_) => const LoginPage()),
//               );
//             }
//           },
//         ),
//       ),
//       backgroundColor: const Color(0xFF2196F3), // Deep blue
//       body: SafeArea(
//         child: SingleChildScrollView(
//           controller: _scrollController,
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildHeader(),
//               const SizedBox(height: 20),
//               _buildQuickActions(),
//               const SizedBox(height: 25),
//               _buildReminderSection(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // HEADER (Dynamic Data)
//   Widget _buildHeader() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "Welcome, $teacherName 👋", // 🔥 Dynamic Name
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               "Department: $departmentName", // 🔥 Dynamic Dept
//               style: const TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ],
//         ),
//         CircleAvatar(
//           radius: 24,
//           backgroundColor: Colors.white,
//           child: IconButton(
//             onPressed: () async {
//               await FirebaseAuth.instance.signOut();
//               if (context.mounted) {
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (context) => const LoginPage()),
//                 );
//               }
//             },
//             icon: const Icon(Icons.logout, color: Colors.blue),
//           ),
//         ),
//       ],
//     );
//   }

//   // QUICK ACTIONS
//   Widget _buildQuickActions() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Quick Actions",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),
//           GridView.count(
//             crossAxisCount: 2,
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             crossAxisSpacing: 12,
//             mainAxisSpacing: 12,
//             children: [
//               // students list page navigation
//               _actionCard(
//                 context: context,
//                 icon: Icons.people,
//                 title: "Students",
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => const StudentStudentsListPage(),
//                     ),
//                   );
//                 },
//               ),
//               // internals page navigation
//               _actionCard(
//                 context: context,
//                 icon: Icons.assignment,
//                 title: "Internals",
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => const InternalMarksPage(),
//                     ),
//                   );
//                 },
//               ),
//               // Attendance
//               _actionCard(
//                 context: context,
//                 icon: Icons.check_circle_outline,
//                 title: "Attendance",
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => const AttendanceDailyPage(),
//                     ),
//                   );
//                 },
//               ),
//               //  timetable (Placeholder)
//               _actionCard(
//                 context: context,
//                 icon: Icons.calendar_month,
//                 title: "TimeTable",
//                 onTap: () {
//                   // Reusing AttendancePage as placeholder
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => const AttendanceDailyPage(),
//                     ),
//                   );
//                 },
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // SINGLE ACTION CARD
//   Widget _actionCard({
//     required BuildContext context,
//     required IconData icon,
//     required String title,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.blue.shade100),
//         ),
//         padding: const EdgeInsets.all(14),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 34, color: Colors.blue.shade800),
//             const SizedBox(height: 10),
//             Text(
//               title,
//               textAlign: TextAlign.center,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // REMINDERS / TO-DO LIST
//   Widget _buildReminderSection() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // TITLE + ADD BUTTON
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 "Tasks & Reminders",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.add, color: Colors.blue),
//                 onPressed: _addReminder,
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),

//           // REMINDER LIST
//           ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: reminders.length,
//             itemBuilder: (context, index) {
//               final reminder = reminders[index];

//               return Dismissible(
//                 key: UniqueKey(),
//                 direction: DismissDirection.endToStart,
//                 background: Container(
//                   color: Colors.red,
//                   alignment: Alignment.centerRight,
//                   padding: const EdgeInsets.only(right: 20),
//                   child: const Icon(Icons.delete, color: Colors.white),
//                 ),
//                 onDismissed: (_) {
//                   setState(() {
//                     reminders.removeAt(index);
//                   });
//                 },
//                 child: Column(
//                   children: [
//                     ListTile(
//                       // CHECKBOX → AUTO DELETE
//                       leading: Checkbox(
//                         value: false,
//                         onChanged: (_) {
//                           setState(() {
//                             reminders.removeAt(index);
//                           });
//                         },
//                       ),

//                       // EDITABLE TITLE
//                       title: Padding(
//                         padding: const EdgeInsets.only(bottom: 8.0),
//                         child: TextFormField(
//                           initialValue: reminder["title"],
//                           decoration: const InputDecoration(
//                             border: InputBorder.none,
//                             isDense: true,
//                             hintText: "Title",
//                           ),
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                           onChanged: (value) {
//                             reminder["title"] = value;
//                           },
//                         ),
//                       ),

//                       // EDITABLE SUBTITLE
//                       subtitle: TextFormField(
//                         initialValue: reminder["subtitle"],
//                         decoration: const InputDecoration(
//                           border: InputBorder.none,
//                           isDense: true,
//                           hintText: "Description or Date",
//                         ),
//                         style: const TextStyle(color: Colors.grey),
//                         onChanged: (value) {
//                           reminder["subtitle"] = value;
//                         },
//                       ),
//                     ),
//                     const Divider(color: Colors.black),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // ADD NEW REMINDER
//   void _addReminder() {
//     setState(() {
//       reminders.add({"title": "New Task", "subtitle": "Subject/Deadline"});
//     });
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _scrollController.animateTo(
//         _scrollController.position.maxScrollExtent,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     });
//   }
// }
