import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
          backgroundColor: AppTheme.cyan.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}
