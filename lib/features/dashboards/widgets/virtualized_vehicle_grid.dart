import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class VirtualizedVehicleGrid<T> extends StatelessWidget {
  final List<T> items;
  final int crossAxisCount;
  final Widget Function(BuildContext, T) itemBuilder;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const VirtualizedVehicleGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 5,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return itemBuilder(context, items[index]);
      },
    );
  }
}
