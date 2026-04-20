import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';

class PrimaryBottomButton extends StatelessWidget {
  final String title;
  final VoidCallback callback;

  const PrimaryBottomButton({
    super.key,
    required this.title,
    required this.callback,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: () => callback(),
        style: ElevatedButton.styleFrom(shape: StadiumBorder()),
        child: Text(title),
      ),
    );
  }
}

class SecondaryBottomButton extends StatelessWidget {
  final String title;
  final VoidCallback? callback;

  const SecondaryBottomButton({
    super.key,
    required this.title,
    required this.callback,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          foregroundColor: ColorManager.formTitle(context),
          backgroundColor: ColorManager.secondaryButtonBackground(context),
          shape: StadiumBorder(),
        ),
        child: Text(title),
      ),
    );
  }
}
