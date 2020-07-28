import 'dart:async';
import 'dart:math';

import 'package:flokk/_internal/components/mouse_hover_builder.dart';
import 'package:flokk/_internal/components/simple_value_notifier.dart';
import 'package:flokk/app_extensions.dart';
import 'package:flokk/class_extensions.dart';
import 'package:flokk/styles.dart';
import 'package:flokk/themes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StyledScrollbar extends StatefulWidget {
  final double size;
  final Axis axis;
  final ScrollController controller;
  final Function(double) onDrag;
  final bool showTrack;
  final Color handleColor;
  final Color trackColor;
  final Duration timeToFade;

  // TODO: Remove contentHeight if we can fix this issue
  // https://stackoverflow.com/questions/60855712/flutter-how-to-force-scrollcontroller-to-recalculate-position-maxextents
  final double contentSize;

  const StyledScrollbar(
      {Key key, this.size, this.axis, this.controller, this.onDrag, this.contentSize, this.showTrack = false, this.handleColor, this.trackColor, this.timeToFade = const Duration(seconds: 1), })
      : super(key: key);

  @override
  ScrollbarState createState() => ScrollbarState();
}

class ScrollbarState extends State<StyledScrollbar> {
  double _viewExtent = 100;
  SimpleNotifier buildNotifier = SimpleNotifier();
  Timer _fadeoutTimer;
  bool showHandle = false;

  @override
  void dispose() {
    _fadeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    var isMobile = UniversalPlatformExt.isMobile;
    widget.controller.addListener(() {
      setState(() {
        if (isMobile) {
          showHandle = true;
        }
      });
      if (isMobile) {
        _restartFadeOutTimer();
      }
    });
    super.initState();
  }

  @override
  void didUpdateWidget(StyledScrollbar oldWidget) {
    if (oldWidget.contentSize != widget.contentSize) {
      setState(() {});
    }
    super.didUpdateWidget(oldWidget);
  }

//  void calculateSize() {
//    //[SB] Only hack I can find  to make the ScrollController update it's maxExtents.
//    //Call this whenever the content changes, so the scrollbar can recalculate it's size
//    widget.controller.jumpTo(widget.controller.position.pixels + 1);
//    Future.microtask(() => widget.controller
//        .animateTo(widget.controller.position.pixels - 1, duration: 100.milliseconds, curve: Curves.linear));
//  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) {
        double maxExtent;
        switch (widget.axis) {
          case Axis.vertical:
            // Use supplied contentSize if we have it, otherwise just fallback to maxScrollExtents
            maxExtent = (widget.contentSize != null && widget.contentSize > 0)
                ? widget.contentSize - constraints.maxHeight
                : widget.controller?.position?.maxScrollExtent ?? 0;
            _viewExtent = constraints.maxHeight;

            break;
          case Axis.horizontal:
            // Use supplied contentSize if we have it, otherwise just fallback to maxScrollExtents
            maxExtent = (widget.contentSize != null && widget.contentSize > 0)
                ? widget.contentSize - constraints.maxWidth
                : widget.controller?.position?.maxScrollExtent ?? 0;
            _viewExtent = constraints.maxWidth;

            break;
        }

        double contentExtent = maxExtent + _viewExtent;
        // Calculate the alignment for the handle, this is a value between 0 and 1,
        // it automatically takes the handle size into acct
        double handleAlignment = maxExtent == 0 ? 0 : widget.controller.offset / maxExtent;

        // Convert handle alignment from [0, 1] to [-1, 1]
        handleAlignment *= 2.0;
        handleAlignment -= 1.0;

        // Calculate handleSize by comparing the total content size to our viewport
        double handleExtent = _viewExtent;
        if (contentExtent > _viewExtent) {
          //Make sure handle is never small than the minSize
          handleExtent = max(60, _viewExtent * _viewExtent / contentExtent);
        }
        // Hide the handle if content is < the viewExtent
        if (!UniversalPlatformExt.isMobile) {
          showHandle = contentExtent > _viewExtent && contentExtent > 0;
        }
        // Handle color
        Color handleColor = widget.handleColor ?? (
            theme.isDark ? theme.greyWeak.withOpacity(.2) : theme.greyWeak);
        // Track color
        Color trackColor = widget.trackColor ?? (
            theme.isDark ? theme.greyWeak.withOpacity(.1) : theme.greyWeak.withOpacity(.3));

        //Layout the stack, it just contains a child, and
        return Stack(children: <Widget>[
          /// TRACK, thin strip, aligned along the end of the parent
          if (widget.showTrack)
            Align(
              alignment: Alignment(1, 1),
              child: Container(
                color: trackColor,
                width: widget.axis == Axis.vertical ? widget.size : double.infinity,
                height: widget.axis == Axis.horizontal ? widget.size : double.infinity,
              ),
            ),

          /// HANDLE - Clickable shape that changes scrollController when dragged
          Align(
            // Use calculated alignment to position handle from -1 to 1, let Alignment do the rest of the work
            alignment: Alignment(
              widget.axis == Axis.vertical ? 1 : handleAlignment,
              widget.axis == Axis.horizontal ? 1 : handleAlignment,
            ),
            child: GestureDetector(
              onVerticalDragUpdate: _handleVerticalDrag,
              onHorizontalDragUpdate: _handleHorizontalDrag,
              // HANDLE SHAPE
              child: MouseHoverBuilder(
                builder: (_, isHovered) => Container(
                  width: widget.axis == Axis.vertical ? widget.size : handleExtent,
                  height: widget.axis == Axis.horizontal ? widget.size : handleExtent,
                  decoration: BoxDecoration(color: handleColor.withOpacity(isHovered? 1 : .85), borderRadius: Corners.s3Border),
                ),
              ),
            ),
          )
        ]).opacity(showHandle ? 1.0 : 0.0, animate: true);
      },
    );
  }

  void _handleHorizontalDrag(DragUpdateDetails details) {
    double pos = widget.controller.offset;
    double pxRatio = (widget.controller.position.maxScrollExtent + _viewExtent) / _viewExtent;
    widget.controller.jumpTo((pos + details.delta.dx * pxRatio).clamp(0.0, widget.controller.position.maxScrollExtent));
    widget.onDrag?.call(details.delta.dx);
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    double pos = widget.controller.offset;
    double pxRatio = (widget.controller.position.maxScrollExtent + _viewExtent) / _viewExtent;
    widget.controller.jumpTo((pos + details.delta.dy * pxRatio).clamp(0.0, widget.controller.position.maxScrollExtent));
    widget.onDrag?.call(details.delta.dy);
  }

  void _restartFadeOutTimer() {
    setState(() {
      showHandle = true;
    });
    _fadeoutTimer?.cancel();
    _fadeoutTimer = Timer(widget.timeToFade, () {
      setState(() {
        showHandle = false;
      });
      _fadeoutTimer = null;
    });
  }
}

class ScrollbarListStack extends StatelessWidget {
  final double barSize;
  final Axis axis;
  final ChangeNotifier rebuildNotifier;
  final Widget child;
  final ScrollController controller;
  final double contentSize;
  final EdgeInsets scrollbarPadding;
  final Color handleColor;
  final Color trackColor;

  const ScrollbarListStack(
      {Key key, this.barSize, this.axis, this.rebuildNotifier, this.child, this.controller, this.contentSize, this.scrollbarPadding, this.handleColor, this.trackColor })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        /// LIST
        /// Wrap with a bit of padding on the right
        child.padding(
          right: axis == Axis.vertical && !UniversalPlatformExt.isMobile ? barSize + Insets.sm : 0,
          bottom: axis == Axis.horizontal && !UniversalPlatformExt.isMobile ? barSize + Insets.sm : 0,
        ),

        /// SCROLLBAR
        Padding(
          padding: scrollbarPadding ?? EdgeInsets.zero,
          child: StyledScrollbar(
            size: barSize,
            axis: axis,
            controller: controller,
            contentSize: contentSize,
            trackColor: trackColor,
            handleColor: handleColor,
            showTrack: true,
          ),
        ),
      ],
    );
  }
}
