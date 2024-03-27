import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../ui.dart';

class PlutoColumnTitle extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  late final double height;

  PlutoColumnTitle({
    required this.stateManager,
    required this.column,
    double? height,
  })  : height = height ?? stateManager.columnHeight,
        super(key: ValueKey('column_title_${column.key}'));

  @override
  PlutoColumnTitleState createState() => PlutoColumnTitleState();
}

class PlutoColumnTitleState extends PlutoStateWithChange<PlutoColumnTitle> {
  late Offset _columnRightPosition;

  bool _isPointMoving = false;

  PlutoColumnSort _sort = PlutoColumnSort.none;

  bool _isHoveringIcon = false;

  bool get showContextIcon {
    return widget.column.enableContextMenu ||
        widget.column.enableDropToResize ||
        !_sort.isNone;
  }

  bool get enableGesture {
    return widget.column.enableContextMenu || widget.column.enableDropToResize;
  }

  MouseCursor get contextMenuCursor {
    if (enableGesture) {
      return widget.column.enableDropToResize
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.click;
    }

    return SystemMouseCursors.basic;
  }

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _sort = update<PlutoColumnSort>(
      _sort,
      widget.column.sort,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    List<PopupMenuEntry> items = stateManager.columnMenuDelegate.buildMenuItems(
      stateManager: stateManager,
      column: widget.column,
    );

    final selected = await stateManager.columnMenuDelegate.showColumnMenu(
      context: context,
      position: position,
      items: items,
    );

    if (context.mounted) {
      stateManager.columnMenuDelegate.onSelected(
        context: context,
        stateManager: stateManager,
        column: widget.column,
        mounted: mounted,
        selected: selected,
      );
    }
  }

  void _handleOnPointDown(PointerDownEvent event) {
    _isPointMoving = false;

    _columnRightPosition = event.position;
  }

  void _handleOnPointMove(PointerMoveEvent event) {
    // if at least one movement event has distanceSquared > 0.5 _isPointMoving will be true
    _isPointMoving |=
        (_columnRightPosition - event.position).distanceSquared > 0.5;

    if (!_isPointMoving) return;

    final moveOffset = event.position.dx - _columnRightPosition.dx;

    final bool isLTR = stateManager.isLTR;

    stateManager.resizeColumn(widget.column, isLTR ? moveOffset : -moveOffset);

    _columnRightPosition = event.position;
  }

  void _handleOnPointUp(PointerUpEvent event) {
    if (_isPointMoving) {
      stateManager.updateCorrectScrollOffset();
    } else if (mounted && widget.column.enableContextMenu) {
      _showContextMenu(context, event.position);
    }

    _isPointMoving = false;
  }

  Widget _titleIcons() {
    final style = stateManager.configuration.style;

    bool isViewNormal =
        stateManager.configuration.style.columnIconViewType.isNormal;

    Widget? leadingIcon;

    try {
      leadingIcon = stateManager.columnMenuDelegate.leadingIcon(widget.column);
    } catch (e) {
      leadingIcon;
    }

    Widget sortIcon = Visibility(
      visible: _isHoveringIcon || isViewNormal || isSortingIcon(),
      child: PlutoGridColumnSortIcon(
        sort: _sort,
        ascendingIcon: style.columnAscendingIcon,
        descendingIcon: style.columnDescendingIcon,
      ),
    );

    Widget icon = PlutoGridColumnIcon(
      color: style.iconColor,
      icon: widget.column.enableContextMenu
          ? style.columnContextIcon
          : style.columnResizeIcon,
    );

    Widget iconButton = Visibility(
      visible: _isHoveringIcon || isViewNormal || leadingIcon != null,
      child: IconButton(
        icon: leadingIcon ?? icon,
        iconSize: style.iconSize,
        mouseCursor: SystemMouseCursors.click,
        onPressed: null,
      ),
    );

    Widget dragging = MouseRegion(
      cursor: contextMenuCursor,
      hitTestBehavior: HitTestBehavior.translucent,
      child: Container(width: 5),
    );

    return Row(
      children: [
        iconButton,
        sortIcon,
        dragging,
      ],
    );
  }

  bool isSortingIcon() {
    switch (_sort) {
      case PlutoColumnSort.ascending:
      case PlutoColumnSort.descending:
        return true;

      case PlutoColumnSort.none:
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final columnWidget = _SortableWidget(
      stateManager: stateManager,
      column: widget.column,
      child: _ColumnWidget(
        stateManager: stateManager,
        column: widget.column,
        height: widget.height,
      ),
    );

    final contextMenuIcon = SizedBox(
      height: widget.height,
      child: Align(
        alignment: Alignment.center,
        child: _titleIcons(),
      ),
    );

    Color? columnColor =
        stateManager.configuration.style.columnsBackgroundColor;

    Color? columnHoverColor =
        stateManager.configuration.style.columnsBackgroundHoverColor ??
            columnColor;

    return mouseHouverTitle(
      Container(
        color: _isHoveringIcon ? columnHoverColor : columnColor,
        child: Stack(
          children: [
            title(columnWidget),
            if (showContextIcon) buildIcons(contextMenuIcon),
          ],
        ),
      ),
    );
  }

  Widget mouseHouverTitle(Widget child) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringIcon = true),
      onExit: (_) => setState(() => _isHoveringIcon = false),
      child: child,
    );
  }

  Positioned buildIcons(SizedBox contextMenuIcon) {
    return Positioned.directional(
      textDirection: stateManager.textDirection,
      end: 0,
      child: enableGesture
          ? Listener(
              onPointerDown: _handleOnPointDown,
              onPointerMove: _handleOnPointMove,
              onPointerUp: _handleOnPointUp,
              behavior: HitTestBehavior.translucent,
              child: contextMenuIcon,
            )
          : contextMenuIcon,
    );
  }

  Positioned title(_SortableWidget columnWidget) {
    return Positioned(
      left: 0,
      right: 0,
      child: widget.column.enableColumnDrag
          ? _DraggableWidget(
              stateManager: stateManager,
              column: widget.column,
              child: columnWidget,
            )
          : columnWidget,
    );
  }
}

class PlutoGridColumnIcon extends StatelessWidget {
  final Color color;

  final IconData icon;

  const PlutoGridColumnIcon({
    this.color = Colors.black26,
    this.icon = Icons.dehaze,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color);
  }
}

class PlutoGridColumnSortIcon extends StatelessWidget {
  final PlutoColumnSort? sort;

  final Icon? ascendingIcon;

  final Icon? descendingIcon;

  const PlutoGridColumnSortIcon({
    this.sort,
    this.ascendingIcon,
    this.descendingIcon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: sort != PlutoColumnSort.none,
      child: getIcon(),
    );
  }

  Widget getIcon() {
    switch (sort) {
      case PlutoColumnSort.ascending:
        return ascendingIcon == null
            ? Transform.rotate(
                angle: 90 * pi / 90,
                child: const Icon(
                  Icons.sort,
                  color: Colors.green,
                ),
              )
            : ascendingIcon!;
      case PlutoColumnSort.descending:
        return descendingIcon == null
            ? const Icon(
                Icons.sort,
                color: Colors.red,
              )
            : descendingIcon!;

      default:
        return Container();
    }
  }
}

class _DraggableWidget extends StatelessWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final Widget child;

  const _DraggableWidget({
    required this.stateManager,
    required this.column,
    required this.child,
    Key? key,
  }) : super(key: key);

  void _handleOnPointerMove(PointerMoveEvent event) {
    stateManager.eventManager!.addEvent(PlutoGridScrollUpdateEvent(
      offset: event.position,
      scrollDirection: PlutoGridScrollUpdateDirection.horizontal,
    ));
  }

  void _handleOnPointerUp(PointerUpEvent event) {
    PlutoGridScrollUpdateEvent.stopScroll(
      stateManager,
      PlutoGridScrollUpdateDirection.horizontal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: _handleOnPointerMove,
      onPointerUp: _handleOnPointerUp,
      child: Draggable<PlutoColumn>(
        data: column,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: PlutoShadowContainer(
            alignment: column.titleTextAlign.alignmentValue,
            width: PlutoGridSettings.minColumnWidth,
            height: stateManager.columnHeight,
            backgroundColor:
                stateManager.configuration.style.gridBackgroundColor,
            borderColor:
                stateManager.configuration.style.gridBorderColor ?? Colors.red,
            child: Text(
              column.title,
              style: stateManager.configuration.style.columnTextStyle.copyWith(
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SortableWidget extends StatelessWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final Widget child;

  const _SortableWidget({
    Key? key,
    required this.stateManager,
    required this.column,
    required this.child,
  }) : super(key: key);

  void _onTap() {
    stateManager.toggleSortColumn(column);
  }

  @override
  Widget build(BuildContext context) {
    return column.enableSorting
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const ValueKey('ColumnTitleSortableGesture'),
              onTap: _onTap,
              child: child,
            ),
          )
        : child;
  }
}

class _ColumnWidget extends StatelessWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final double height;

  const _ColumnWidget({
    required this.stateManager,
    required this.column,
    required this.height,
    Key? key,
  }) : super(key: key);

  EdgeInsets get padding =>
      column.titlePadding ??
      stateManager.configuration.style.defaultColumnTitlePadding;

  bool get showSizedBoxForIcon =>
      column.isShowRightIcon &&
      (column.titleTextAlign.isRight || stateManager.isRTL);

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlutoColumn>(
      onWillAcceptWithDetails: (details) => acceptColumnToDrag(details.data),
      onAcceptWithDetails: (details) => acceptColumnToMove(details.data),
      builder: (dragContext, candidate, rejected) {
        final bool noDragTarget = candidate.isEmpty;

        bool hasLeadingIcon = false;

        try {
          hasLeadingIcon =
              stateManager.columnMenuDelegate.leadingIcon(column) != null;
        } catch (e) {
          hasLeadingIcon = false;
        }

        final style = stateManager.style;

        return SizedBox(
          width: column.width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: noDragTarget
                  ? column.backgroundColor
                  : style.dragTargetColumnColor,
              border: BorderDirectional(
                end: column.enableColumnBorderVertical ??
                        style.enableColumnBorderVertical
                    ? BorderSide(color: style.borderColor, width: 1.0)
                    : BorderSide.none,
              ),
            ),
            child: Container(
              margin: hasLeadingIcon ? const EdgeInsets.only(right: 25) : null,
              padding: padding,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (column.enableRowChecked)
                      CheckboxAllSelectionWidget(stateManager: stateManager),
                    Expanded(
                      child: _ColumnTextWidget(
                        column: column,
                        stateManager: stateManager,
                        height: height,
                      ),
                    ),
                    if (showSizedBoxForIcon) SizedBox(width: style.iconSize),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void acceptColumnToMove(PlutoColumn columnToMove) {
    if (columnToMove.key != column.key) {
      stateManager.moveColumn(column: columnToMove, targetColumn: column);
    }
  }

  bool acceptColumnToDrag(PlutoColumn? columnToDrag) {
    return columnToDrag != null &&
        columnToDrag.key != column.key &&
        !stateManager.limitMoveColumn(
          column: columnToDrag,
          targetColumn: column,
        );
  }
}

class CheckboxAllSelectionWidget extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  const CheckboxAllSelectionWidget({required this.stateManager, Key? key})
      : super(key: key);

  @override
  CheckboxAllSelectionWidgetState createState() =>
      CheckboxAllSelectionWidgetState();
}

class CheckboxAllSelectionWidgetState
    extends PlutoStateWithChange<CheckboxAllSelectionWidget> {
  bool? _checked;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _checked = update<bool?>(
      _checked,
      stateManager.tristateCheckedRow,
    );
  }

  void _handleOnChanged(bool? changed) {
    if (changed == _checked) {
      return;
    }

    changed ??= false;

    if (_checked == null) changed = true;

    stateManager.toggleAllRowChecked(changed);

    if (stateManager.onRowChecked != null) {
      stateManager.onRowChecked!(
        PlutoGridOnRowCheckedAllEvent(isChecked: changed),
      );
    }

    setState(() {
      _checked = changed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlutoScaledCheckbox(
      value: _checked,
      handleOnChanged: _handleOnChanged,
      tristate: true,
      scale: 0.86,
      unselectedColor: stateManager.configuration.style.iconColor,
      activeColor: stateManager.configuration.style.activatedBorderColor,
      checkColor: stateManager.configuration.style.activatedColor,
    );
  }
}

class _ColumnTextWidget extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  final PlutoColumn column;

  final double height;

  const _ColumnTextWidget({
    required this.stateManager,
    required this.column,
    required this.height,
    Key? key,
  }) : super(key: key);

  @override
  _ColumnTextWidgetState createState() => _ColumnTextWidgetState();
}

class _ColumnTextWidgetState extends PlutoStateWithChange<_ColumnTextWidget> {
  bool _isFilteredList = false;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _isFilteredList = update<bool>(
      _isFilteredList,
      stateManager.isFilteredColumn(widget.column),
    );
  }

  void _handleOnPressedFilter() {
    stateManager.showFilterPopup(
      context,
      calledColumn: widget.column,
    );
  }

  String? get _title =>
      widget.column.titleSpan == null ? widget.column.title : null;

  List<InlineSpan> get _children => [
        if (widget.column.titleSpan != null)
          widget.column.titleSpan!(
            PlutoColumnContext(
              column: widget.column,
              stateManager: stateManager,
            ),
          ),
        if (_isFilteredList)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: IconButton(
              icon: Icon(
                Icons.filter_alt_outlined,
                color: stateManager.configuration.style.iconColor,
                size: stateManager.configuration.style.iconSize,
              ),
              onPressed: _handleOnPressedFilter,
              constraints: BoxConstraints(
                maxHeight:
                    widget.height + (PlutoGridSettings.rowBorderWidth * 2),
              ),
            ),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: _title,
        children: _children,
      ),
      style: stateManager.configuration.style.columnTextStyle,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      maxLines: 1,
      textAlign: widget.column.titleTextAlign.value,
    );
  }
}
