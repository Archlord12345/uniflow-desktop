import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'surface_card.dart';

/// Colonne d'un [AppDataTable].
class AppColumn {
  final String label;

  /// Poids relatif de la colonne (`flex`). Une colonne d'actions prend 0 et
  /// une largeur fixe via [width].
  final int flex;
  final double? width;
  final TextAlign align;

  const AppColumn(this.label,
      {this.flex = 1, this.width, this.align = TextAlign.left});
}

/// Tableau stylé du design system (`table.tsx` du web) : en-tête en petites
/// majuscules atténuées sur fond gris très clair, lignes séparées d'un trait
/// `#e5e7eb`, survol qui teinte la ligne, tout dans une [SurfaceCard].
///
/// Construit sur `Row`/`Expanded` plutôt que `DataTable` : `DataTable`
/// impose sa largeur intrinsèque et déborde sur une fenêtre étroite, ce que
/// le test de mise en page signalait ; ici les colonnes se partagent la
/// largeur disponible et tronquent leur texte.
class AppDataTable<T> extends StatelessWidget {
  final List<AppColumn> columns;
  final List<T> rows;
  final List<Widget> Function(T row, int index) cells;
  final void Function(T row)? onRowTap;
  final Widget? empty;
  final double rowHeight;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.cells,
    this.onRowTap,
    this.empty,
    this.rowHeight = 52,
  });

  Widget _cell(AppColumn column, Widget child) {
    final aligned = Align(
      alignment: switch (column.align) {
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        TextAlign.center => Alignment.center,
        _ => Alignment.centerLeft,
      },
      child: child,
    );
    if (column.width != null) {
      return SizedBox(width: column.width, child: aligned);
    }
    return Expanded(flex: column.flex, child: aligned);
  }

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colors.surfaceMuted,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.md),
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  _cell(
                    columns[i],
                    Text(
                      columns[i].label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextStyles.overline.copyWith(color: colors.muted),
                    ),
                  ),
                  if (i < columns.length - 1)
                    const SizedBox(width: AppSpacing.md),
                ],
              ],
            ),
          ),
          if (rows.isEmpty)
            empty ??
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Text('Aucune ligne.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(color: colors.muted)),
                )
          else
            for (var index = 0; index < rows.length; index++)
              _TableRow(
                height: rowHeight,
                onTap: onRowTap == null ? null : () => onRowTap!(rows[index]),
                last: index == rows.length - 1,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    _cell(columns[i], cells(rows[index], index)[i]),
                    if (i < columns.length - 1)
                      const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final List<Widget> children;
  final VoidCallback? onTap;
  final bool last;
  final double height;

  const _TableRow({
    required this.children,
    required this.onTap,
    required this.last,
    required this.height,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = UniFlowColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: BoxConstraints(minHeight: widget.height),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: _hover
                  ? colors.primary.withValues(alpha: 0.04)
                  : Colors.transparent,
              border: widget.last
                  ? null
                  : Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(children: widget.children),
          ),
        ),
      ),
    );
  }
}
