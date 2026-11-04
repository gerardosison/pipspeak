import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Processing routes cannot be resumed from a URL without their live request.
class WorkflowRecovery extends StatelessWidget {
  const WorkflowRecovery({super.key, required this.returnPath});
  final String returnPath;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This practice or analysis request is no longer active.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(returnPath),
                child: const Text('Start again'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
