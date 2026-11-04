import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One entry of a [DockMenu]: a round button with a label next to it.
class DockItem {
  const DockItem({
    this.icon,
    this.text,
    required this.label,
    this.selected = false,
    this.keepOpen = false,
    required this.onTap,
  }) : assert(icon != null || text != null);

  /// Icon of the round button; [text] (e.g. "x2") is shown when it is null.
  final IconData? icon;
  final String? text;
  final String label;
  final bool selected;

  /// Leave the menu open after the tap (e.g. cycling a value).
  final bool keepOpen;
  final VoidCallback onTap;
}

/// A round button of the control bar that, when tapped, makes its entries pop
/// up in a column above it, like the macOS dock.
class DockMenu extends StatefulWidget {
  const DockMenu({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.items,
    required this.barVisible,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Entries, nearest to the button first. Called while the menu is open,
  /// inside an `Obx`, so reading observables in it keeps the menu live.
  final List<DockItem> Function() items;

  /// The menu closes when the control bar hides.
  final RxBool barVisible;

  /// Called on every tap or selection (keeps the control bar visible).
  final VoidCallback? onTap;

  @override
  State<DockMenu> createState() => _DockMenuState();
}

class _DockMenuState extends State<DockMenu>
    with SingleTickerProviderStateMixin {
  static const _size = 56.0;

  final _link = LayerLink();
  final _portal = OverlayPortalController();
  // created in initState, not lazily: a lazy controller that was never used
  // would be created by dispose(), when the element is already deactivated
  late final AnimationController _anim;
  Worker? _barWorker;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _barWorker = ever<bool>(widget.barVisible, (visible) {
      if (!visible) _close();
    });
  }

  @override
  void dispose() {
    _barWorker?.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    widget.onTap?.call();
    _open ? _close() : _openMenu();
  }

  void _openMenu() {
    _portal.show();
    _anim.forward(from: 0);
    setState(() => _open = true);
  }

  Future<void> _close() async {
    if (!_open) return;
    setState(() => _open = false);
    await _anim.reverse();
    if (!_open && mounted) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: Tooltip(
          message: widget.tooltip,
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                  color: _open ? const Color(0x4DFFFFFF) : const Color(0x1FFFFFFF),
                  shape: BoxShape.circle),
              child: Icon(widget.icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(children: [
      // a tap anywhere else closes the menu
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _close,
        ),
      ),
      CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -10),
        child: Obx(() {
          final items = widget.items();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            verticalDirection: VerticalDirection.up,
            children: [
              for (var i = 0; i < items.length; i++)
                _entry(items[i], i, items.length),
            ],
          );
        }),
      ),
    ]);
  }

  Widget _entry(DockItem item, int index, int count) {
    // the nearest entry appears first, the farthest last
    final start = count <= 1 ? 0.0 : 0.55 * index / (count - 1);
    final t = CurvedAnimation(
        parent: _anim,
        curve: Interval(start, start + 0.45, curve: Curves.easeOutBack),
        reverseCurve: Curves.easeIn);
    final selected = item.selected;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedBuilder(
        animation: t,
        builder: (context, child) => Opacity(
          opacity: t.value.clamp(0.0, 1.0),
          child: Transform.scale(
              scale: 0.4 + 0.6 * t.value,
              alignment: Alignment.bottomLeft,
              child: child),
        ),
        child: GestureDetector(
          onTap: () {
            widget.onTap?.call();
            item.onTap();
            if (!item.keepOpen) _close();
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: _size,
              height: _size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xF0262A2E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: item.icon != null
                  ? Icon(item.icon,
                      color: selected ? Colors.black87 : Colors.white)
                  : Text(item.text!,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.black87 : Colors.white)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xE60A0C0E),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(item.label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400)),
            ),
          ]),
        ),
      ),
    );
  }
}
