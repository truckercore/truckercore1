import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Unified empty/error/loading state (with iconography, retry, and AnimatedSwitcher)
/// - Works standalone or as a wrapper around a builder.
class DataStateView extends StatelessWidget {
  final bool loading;
  final Object? error;
  final bool isEmpty;
  final VoidCallback? onRetry;
  final Widget Function()? emptyAction;
  final Widget child;
  final String? emptyMessage;
  final String? errorMessage;

  const DataStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    this.onRetry,
    this.emptyAction,
    required this.child,
    this.emptyMessage,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: loading
          ? const Center(
              key: ValueKey('loading'),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: 8),
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Loading…'),
              ]),
            )
          : (error != null
              ? Center(
                  key: const ValueKey('error'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(height: 8),
                      Text(errorMessage ?? 'Something went wrong'),
                      const SizedBox(height: 8),
                      if (onRetry != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          onPressed: onRetry,
                        ),
                    ]),
                  ),
                )
              : (isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.inbox_outlined, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(emptyMessage ?? 'No data yet'),
                          if (emptyAction != null) ...[
                            const SizedBox(height: 8),
                            emptyAction!(),
                          ]
                        ]),
                      ),
                    )
                  : child)),
    );
  }
}

/// Riverpod AsyncValue convenience adapter to keep screens tidy
class AsyncValueView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onRetry;
  final Widget Function(T data) builder;

  const AsyncValueView({super.key, required this.value, this.isEmpty, this.onRetry, required this.builder});

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DataStateView(
        loading: false,
        error: e,
        isEmpty: false,
        onRetry: onRetry,
        child: const SizedBox.shrink(),
      ),
      data: (data) => (isEmpty != null && isEmpty!(data))
          ? const DataStateView(loading: false, error: null, isEmpty: true, child: SizedBox.shrink())
          : builder(data),
    );
  }
}
