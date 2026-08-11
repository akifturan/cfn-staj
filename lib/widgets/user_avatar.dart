import 'dart:convert';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoBase64;
  final String username;
  final double radius;

  const UserAvatar({
    super.key,
    required this.photoBase64,
    required this.username,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photoBase64;
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(base64Decode(photo)),
      );
    }
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      child: Text(initial),
    );
  }
}
