import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final ImageProvider? image;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double borderWidth;
  final Color borderColor;
  final String? heroTag;

  const UserAvatar({
    super.key,
    this.size = 40.0,
    this.image,
    this.imageUrl,
    this.onTap,
    this.borderWidth = 2.0,
    this.borderColor = Colors.white,
    this.heroTag,
    required String name,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget;

    if (image != null) {
      // Use provided ImageProvider if available
      avatarWidget = _buildAvatarContainer(image!);
    } else if (imageUrl != null) {
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
      // Use default asset image
      avatarWidget = _buildAvatarContainer(
        const AssetImage('assets/images/default_avatar.jpg'),
      );
    }

    final wrappedWidget = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
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
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.person, color: Colors.white)),
    );
  }
}
