import 'package:flutter/material.dart';

import '../../../themes/colors.dart';

/// Container Wrapper For Input Fields With Consistent Styling
class InputContainer extends StatelessWidget {
  final List<Widget> children;

  const InputContainer({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 25, offset: const Offset(0, 8))],
      ),
      child: Column(children: children),
    );
  }
}

/// Divider For Separating Input Fields Within The Container
class InputDivider extends StatelessWidget {
  const InputDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.3, color: Colors.grey.shade400);
  }
}
