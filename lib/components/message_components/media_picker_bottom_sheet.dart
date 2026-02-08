import 'package:flutter/material.dart';

class MediaPickerBottomSheet extends StatelessWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback onDocumentPressed;
  final VoidCallback onLocationPressed;
  final VoidCallback onContactPressed;

  const MediaPickerBottomSheet({
    super.key,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.onDocumentPressed,
    required this.onLocationPressed,
    required this.onContactPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.5, // Limit maximum height
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2C3C),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Options Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: [
                _buildOptionItem(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: onGalleryPressed,
                ),
                _buildOptionItem(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: onCameraPressed,
                ),
                _buildOptionItem(
                  icon: Icons.attach_file_outlined,
                  label: 'Document',
                  onTap: onDocumentPressed,
                ),
                _buildOptionItem(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  onTap: onLocationPressed,
                ),
                _buildOptionItem(
                  icon: Icons.contact_page_outlined,
                  label: 'Contact',
                  onTap: onContactPressed,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF0C1D2C),
              borderRadius: BorderRadius.circular(29),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
