import 'package:flutter/material.dart';

typedef ResponsiveItemBuilder = Widget Function(
  BuildContext context,
  int index,
  bool singleColumn,
);

class ResponsiveCollection extends StatelessWidget {
  const ResponsiveCollection({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.singleColumnBreakpoint = 520,
    this.threeColumnBreakpoint = 780,
    this.spacing = 12,
    this.childAspectRatio = 1.35,
  });

  final int itemCount;
  final ResponsiveItemBuilder itemBuilder;
  final double singleColumnBreakpoint;
  final double threeColumnBreakpoint;
  final double spacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = constraints.maxWidth < singleColumnBreakpoint;
          if (singleColumn) {
            return ListView.separated(
              itemCount: itemCount,
              separatorBuilder: (_, __) => SizedBox(height: spacing),
              itemBuilder: (context, index) =>
                  itemBuilder(context, index, true),
            );
          }
          return GridView.count(
            crossAxisCount:
                constraints.maxWidth >= threeColumnBreakpoint ? 3 : 2,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            children: <Widget>[
              for (var index = 0; index < itemCount; index += 1)
                itemBuilder(context, index, false),
            ],
          );
        },
      );
}
