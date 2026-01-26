import 'package:flutter/material.dart';

class ArchiveItem extends StatelessWidget {
  final int archivedCount;
  final VoidCallback onTap;

  const ArchiveItem({
    super.key,
    required this.archivedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              // Archive icon container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[800]!.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.archive, color: Colors.grey, size: 28),
              ),
              const SizedBox(width: 12),

              // Label and count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Archived',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$archivedCount chat${archivedCount != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              const Icon(Icons.chevron_right, color: Colors.grey),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
