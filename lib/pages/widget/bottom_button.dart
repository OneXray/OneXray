import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';

class PrimaryBottomButton extends StatelessWidget {
  final String title;
  final VoidCallback? callback;
  final bool loading;

  const PrimaryBottomButton({
    super.key,
    required this.title,
    required this.callback,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: loading ? null : callback,
        style: ElevatedButton.styleFrom(shape: StadiumBorder()),
        child: BottomButtonChild(title: title, loading: loading),
      ),
    );
  }
}

class SecondaryBottomButton extends StatelessWidget {
  final String title;
  final VoidCallback? callback;
  final bool loading;

  const SecondaryBottomButton({
    super.key,
    required this.title,
    required this.callback,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: loading ? null : callback,
        style: ElevatedButton.styleFrom(
          foregroundColor: ColorManager.secondaryButtonForeground(context),
          backgroundColor: ColorManager.secondaryButtonBackground(context),
          shape: StadiumBorder(),
        ),
        child: BottomButtonChild(title: title, loading: loading),
      ),
    );
  }
}

class BottomButtonChild extends StatelessWidget {
  const BottomButtonChild({
    super.key,
    required this.title,
    required this.loading,
  });

  final String title;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return Text(title);
    }
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
