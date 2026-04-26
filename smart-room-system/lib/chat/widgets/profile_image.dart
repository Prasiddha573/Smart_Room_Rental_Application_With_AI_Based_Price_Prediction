import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProfileImage extends StatelessWidget {
  final double size;
  final String imageUrl;

  const ProfileImage({
    super.key,
    required this.size,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(size)),
      child: imageUrl.isNotEmpty
          ? CachedNetworkImage(
              width: size,
              height: size,
              fit: BoxFit.cover,
              imageUrl: imageUrl,
              placeholder: (context, url) => Container(
                width: size,
                height: size,
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: size,
                height: size,
                color: Colors.grey[200],
                child: const Icon(
                  CupertinoIcons.person,
                  color: Colors.grey,
                ),
              ),
            )
          : Container(
              width: size,
              height: size,
              color: Colors.grey[200],
              child: const Icon(
                CupertinoIcons.person,
                color: Colors.grey,
              ),
            ),
    );
  }
}