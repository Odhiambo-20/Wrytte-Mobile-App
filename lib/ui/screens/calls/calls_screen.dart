import 'package:flutter/material.dart';
import 'package:wrytte/components/calls_components/call_item.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  int selectedIndex = 0; // 0 = All, 1 = Missed

  final List<Map<String, dynamic>> allCalls = [
    {
      'name': 'John Doe',
      'time': 'Today, 9:30 AM',
      'callType': CallType.incoming,
      'multipleCalls': false,
      'callCount': 1,
      'avatarUrl': null,
    },
    {
      'name': 'Jane Smith',
      'time': 'Yesterday, 7:12 PM',
      'callType': CallType.missed,
      'multipleCalls': true,
      'callCount': 3,
      'avatarUrl': null,
    },
    {
      'name': 'Alex Johnson',
      'time': 'Monday, 3:50 PM',
      'callType': CallType.outgoing,
      'multipleCalls': false,
      'callCount': 1,
      'avatarUrl': null,
    },
  ];

  List<Map<String, dynamic>> get missedCalls =>
      allCalls.where((call) => call['callType'] == CallType.missed).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 19, 18, 18),
        elevation: 0,
        leading: TextButton(
          onPressed: () {},
          child: const Text(
            'Edit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: const Text(
          'Calls',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_call, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // All / Missed toggle buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton("All", 0),
                const SizedBox(width: 8),
                _buildTabButton("Missed", 1),
              ],
            ),
          ),
          Divider(color: Colors.grey[800], height: 1),

          // Recent label
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Text(
              "Recent",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Calls list
          Expanded(
            child: ListView.builder(
              itemCount:
                  selectedIndex == 0 ? allCalls.length : missedCalls.length,
              itemBuilder: (context, index) {
                final call =
                    selectedIndex == 0 ? allCalls[index] : missedCalls[index];

                return CallItem(
                  name: call['name'],
                  time: call['time'],
                  avatarUrl: call['avatarUrl'],
                  callType: call['callType'],
                  multipleCalls: call['multipleCalls'],
                  callCount: call['callCount'],
                  onCallPressed: () {
                    // handle call press
                  },
                  onTap: () {
                    // handle tap to see call details
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? Color.fromARGB(255, 19, 18, 18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
