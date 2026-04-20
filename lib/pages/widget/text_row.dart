import 'package:flutter/material.dart';

class TextRow extends StatelessWidget {
  final String title;
  final String detail;

  const TextRow({super.key, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            constraints: BoxConstraints(minWidth: 100),
            child: Text(title),
          ),
          Expanded(child: Text(detail, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
