import 'package:flutter/material.dart';
import 'package:wrytte/components/post_components/snipp_item.dart';
import 'package:wrytte/ui/screens/post/widgets/category_chips.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  int selectedTabIndex = 0; // 0 = Posts, 1 = Snipps video
  int selectedCategoryIndex = 0;

  final List<String> categories = [
    "All",
    "Subscriptions",
    "News",
    "Live",
    "Music",
    "Sport",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1013),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SizedBox(width: 40), // for symmetry with search button
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTopTab("Posts", 0),
                    const SizedBox(width: 16),
                    _buildTopTab("Snipps video", 1),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search, color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),

            // Category chips only on Posts tab
            if (selectedTabIndex == 0) ...[
              CategoryChips(
                categories: categories,
                selectedIndex: selectedCategoryIndex,
                onSelected: (index) {
                  setState(() {
                    selectedCategoryIndex = index;
                  });
                },
              ),
              const SizedBox(height: 8),
            ],

            // Content area
            Expanded(
              child: IndexedStack(
                index: selectedTabIndex,
                children: [_buildPostsView(), _buildSnippsView()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTab(String text, int index) {
    final bool isSelected = selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTabIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 2,
            width: 30,
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildPostsView() {
    return const Center(
      child: Text(
        "Posts will be shown here",
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildSnippsView() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: 10, // placeholder until Firebase integration
      itemBuilder: (context, index) {
        return const SnippItem(
          caption:
              "Hello, this is a sample caption for the Snipp video. It can be quite long and will wrap to multiple lines if necessary.",
        );
      },
    );
  }
}
