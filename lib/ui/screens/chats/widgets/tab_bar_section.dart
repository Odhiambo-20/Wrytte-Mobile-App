import 'package:flutter/material.dart';

class TabBarSection extends StatelessWidget {
  const TabBarSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              isScrollable: false, // Changed to false for equal distribution
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.white,
              indicatorWeight: 2.0,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: EdgeInsets.zero,
              tabs: [
                Tab(
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(
                      'Chats',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Tab(
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(
                      'Channels',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Tab(
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(
                      'Groups',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
