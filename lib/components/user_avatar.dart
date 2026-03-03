import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final ImageProvider? image;
  final String? imageUrl;
  final VoidCallback? onTap;
  final String? heroTag;

  const UserAvatar({
    super.key,
    this.size = 40.0,
    this.image,
    this.imageUrl,
    this.onTap,
    this.heroTag,
    required String name,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget;

    if (image != null) {
      // Use provided ImageProvider if available
      avatarWidget = _buildAvatarContainer(image!);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Use CachedNetworkImage if URL is provided
      avatarWidget = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        ),
      );
    } else {
      // Use new icon avatar
      avatarWidget = _buildPlaceholder();
    }

    final wrappedWidget = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: avatarWidget,
      ),
    );

    return heroTag != null
        ? Hero(tag: heroTag!, child: wrappedWidget)
        : wrappedWidget;
  }

  Widget _buildAvatarContainer(ImageProvider imageProvider) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0F2A44), // dark blue background
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: size * 0.5,
          color: Color(0xFF4DA3FF), // light blue icon
        ),
      ),
    );
  }
}
