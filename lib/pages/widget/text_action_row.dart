import 'package:flutter/material.dart';

class TextActionRow extends StatelessWidget {
  final String title;
  final String detail;
  final VoidCallback onTap;
  const TextActionRow({
    super.key,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        child: Row(
          children: [
            Text(title, style: TextStyle(fontSize: 14)),
            const Spacer(),
            Text(detail, style: TextStyle(fontSize: 14)),
            Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
