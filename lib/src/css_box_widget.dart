import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';

class CSSBoxWidget extends StatelessWidget {
  CSSBoxWidget({
    this.key,
    required this.child,
    required this.style,
    this.childIsReplaced = false,
    this.shrinkWrap = false,
  }): super(key: key);

  /// An optional anchor key to use in finding this box
  final AnchorKey? key;

  /// The child to be rendered within the CSS Box.
  final Widget child;

  /// The style to use to compute this box's margins/padding/box decoration/width/height/etc.
  ///
  /// Note that this style will only apply to this box, and will not cascade to its child.
  final Style style;

  /// Indicates whether this child is a replaced element that manages its own width
  /// (e.g. img, video, iframe, audio, etc.)
  final bool childIsReplaced;

  /// Whether or not the content should take its minimum possible width
  /// TODO TODO TODO
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _CSSBoxRenderer(
        width: style.width ?? Width.auto(),
        height: style.height ?? Height.auto(),
        paddingSize: style.padding?.collapsedSize ?? Size.zero,
        borderSize: style.border?.dimensions.collapsedSize ?? Size.zero,
        margins: style.margin ?? Margins.zero,
        display: style.display ?? Display.BLOCK,
        childIsReplaced: childIsReplaced,
        emValue: _calculateEmValue(style, context),
        child: Container(
          decoration: BoxDecoration(
            border: style.border,
            color: style.backgroundColor, //Colors the padding and content boxes
          ),
          width: ((style.display == Display.BLOCK || style.display == Display.LIST_ITEM) && !childIsReplaced && !shrinkWrap)
              ? double.infinity
              : null,
          padding: style.padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

class _CSSBoxRenderer extends MultiChildRenderObjectWidget {
  _CSSBoxRenderer({
    Key? key,
    required Widget child,
    required this.display,
    required this.margins,
    required this.width,
    required this.height,
    required this.borderSize,
    required this.paddingSize,
    required this.childIsReplaced,
    required this.emValue,
  }) : super(key: key, children: [child]);

  /// The Display type of the element
  final Display display;

  /// The computed margin values for this element
  final Margins margins;

  /// The width of the element
  final Width width;

  /// The height of the element
  final Height height;

  /// The collapsed size of the element's border
  final Size borderSize;

  /// The collapsed size of the element's padding
  final Size paddingSize;

  /// Whether or not the child being rendered is a replaced element
  /// (this changes the rules for rendering)
  final bool childIsReplaced;

  /// The calculated size of 1em in pixels
  final double emValue;

  @override
  _RenderCSSBox createRenderObject(BuildContext context) {
    return _RenderCSSBox(
      display: display,
      width: width..normalize(emValue),
      height: height..normalize(emValue),
      margins: _preProcessMargins(margins),
      borderSize: borderSize,
      paddingSize: paddingSize,
      childIsReplaced: childIsReplaced,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderCSSBox renderObject) {
    renderObject
      ..display = display
      ..width = (width..normalize(emValue))
      ..height = (height..normalize(emValue))
      ..margins = _preProcessMargins(margins)
      ..borderSize = borderSize
      ..paddingSize = paddingSize
      ..childIsReplaced = childIsReplaced;
  }

  Margins _preProcessMargins(Margins margins) {
    Margin leftMargin = margins.left ?? Margin.zero();
    Margin rightMargin = margins.right ?? Margin.zero();
    Margin topMargin = margins.top ?? Margin.zero();
    Margin bottomMargin = margins.bottom ?? Margin.zero();

    //Preprocess margins to a pixel value
    leftMargin.normalize(emValue);
    rightMargin.normalize(emValue);
    topMargin.normalize(emValue);
    bottomMargin.normalize(emValue);

    // See https://drafts.csswg.org/css2/#inline-width
    // and https://drafts.csswg.org/css2/#inline-replaced-width
    // and https://drafts.csswg.org/css2/#inlineblock-width
    // and https://drafts.csswg.org/css2/#inlineblock-replaced-width
    if (display == Display.INLINE || display == Display.INLINE_BLOCK) {
      if (margins.left?.unit == Unit.auto) {
        leftMargin = Margin.zero();
      }
      if (margins.right?.unit == Unit.auto) {
        rightMargin = Margin.zero();
      }
    }

    return Margins(
      top: topMargin,
      right: rightMargin,
      bottom: bottomMargin,
      left: leftMargin,
    );
  }
}

/// Implements the CSS layout algorithm
class _RenderCSSBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CSSBoxParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CSSBoxParentData> {
  _RenderCSSBox({
    required Display display,
    required Width width,
    required Height height,
    required Margins margins,
    required Size borderSize,
    required Size paddingSize,
    required bool childIsReplaced,
  })  : _display = display,
        _width = width,
        _height = height,
        _margins = margins,
        _borderSize = borderSize,
        _paddingSize = paddingSize,
        _childIsReplaced = childIsReplaced;

  Display _display;

  Display get display => _display;

  set display(Display display) {
    _display = display;
    markNeedsLayout();
  }

  Width _width;

  Width get width => _width;

  set width(Width width) {
    _width = width;
    markNeedsLayout();
  }

  Height _height;

  Height get height => _height;

  set height(Height height) {
    _height = height;
    markNeedsLayout();
  }

  Margins _margins;

  Margins get margins => _margins;

  set margins(Margins margins) {
    _margins = margins;
    markNeedsLayout();
  }

  Size _borderSize;

  Size get borderSize => _borderSize;

  set borderSize(Size size) {
    _borderSize = size;
    markNeedsLayout();
  }

  Size _paddingSize;

  Size get paddingSize => _paddingSize;

  set paddingSize(Size size) {
    _paddingSize = size;
    markNeedsLayout();
  }

  bool _childIsReplaced;

  bool get childIsReplaced => _childIsReplaced;

  set childIsReplaced(bool childIsReplaced) {
    _childIsReplaced = childIsReplaced;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CSSBoxParentData)
      child.parentData = CSSBoxParentData();
  }

  static double getIntrinsicDimension(RenderBox? firstChild,
      double Function(RenderBox child) mainChildSizeGetter) {
    double extent = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      final CSSBoxParentData childParentData =
          child.parentData! as CSSBoxParentData;
      extent = math.max(extent, mainChildSizeGetter(child));
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    return extent;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return getIntrinsicDimension(
        firstChild, (RenderBox child) => child.getMinIntrinsicWidth(height));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return getIntrinsicDimension(
        firstChild, (RenderBox child) => child.getMaxIntrinsicWidth(height));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return getIntrinsicDimension(
        firstChild, (RenderBox child) => child.getMinIntrinsicHeight(width));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return getIntrinsicDimension(
        firstChild, (RenderBox child) => child.getMaxIntrinsicHeight(width));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
    ).parentSize;
  }

  _Sizes _computeSize(
      {required BoxConstraints constraints,
      required ChildLayouter layoutChild}) {
    if (childCount == 0) {
      return _Sizes(constraints.biggest, Size.zero);
    }

    Size containingBlockSize = constraints.biggest;
    double width = containingBlockSize.width;
    double height = containingBlockSize.height;

    RenderBox? child = firstChild;
    assert(child != null);

    // Calculate child size
    final childConstraints = constraints.copyWith(
      maxWidth: (this.width.unit != Unit.auto)
          ? this.width.value
          : constraints.maxWidth -
              (this.margins.left?.value ?? 0) -
              (this.margins.right?.value ?? 0),
      maxHeight: constraints.maxHeight -
          (this.margins.top?.value ?? 0) -
          (this.margins.bottom?.value ?? 0),
      minWidth: 0,
      minHeight: 0,
    );
    final Size childSize = layoutChild(child!, childConstraints);

    // Calculate used values of margins based on rules
    final usedMargins = _calculateUsedMargins(childSize, containingBlockSize);
    final horizontalMargins =
        (usedMargins.left?.value ?? 0) + (usedMargins.right?.value ?? 0);
    final verticalMargins =
        (usedMargins.top?.value ?? 0) + (usedMargins.bottom?.value ?? 0);

    //Calculate Width and Height of CSS Box
    height = childSize.height;
    switch (display) {
      case Display.BLOCK:
        width = containingBlockSize.width;
        height = childSize.height + verticalMargins;
        break;
      case Display.INLINE:
        width = childSize.width + horizontalMargins;
        height = childSize.height;
        break;
      case Display.INLINE_BLOCK:
        width = childSize.width + horizontalMargins;
        height = childSize.height + verticalMargins;
        break;
      case Display.LIST_ITEM:
        width = containingBlockSize.width;
        height = childSize.height + verticalMargins;
        break;
      case Display.NONE:
        width = 0;
        height = 0;
        break;
    }

    return _Sizes(constraints.constrain(Size(width, height)), childSize);
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;

    final sizes = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );
    size = sizes.parentSize;

    RenderBox? child = firstChild;
    while (child != null) {
      final CSSBoxParentData childParentData =
          child.parentData! as CSSBoxParentData;

      // Calculate used margins based on constraints and child size
      final usedMargins =
          _calculateUsedMargins(sizes.childSize, constraints.biggest);
      final leftMargin = usedMargins.left?.value ?? 0;
      final topMargin = usedMargins.top?.value ?? 0;

      double leftOffset = 0;
      double topOffset = 0;
      switch (display) {
        case Display.BLOCK:
          leftOffset = leftMargin;
          topOffset = topMargin;
          break;
        case Display.INLINE:
          leftOffset = leftMargin;
          break;
        case Display.INLINE_BLOCK:
          leftOffset = leftMargin;
          topOffset = topMargin;
          break;
        case Display.LIST_ITEM:
          leftOffset = leftMargin;
          topOffset = topMargin;
          break;
        case Display.NONE:
          //No offset
          break;
      }
      childParentData.offset = Offset(leftOffset, topOffset);

      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
  }

  Margins _calculateUsedMargins(Size childSize, Size containingBlockSize) {
    //We assume that margins have already been preprocessed
    // (i.e. they are non-null and either px units or auto.
    assert(margins.left != null && margins.right != null);
    assert(margins.left!.unit == Unit.px || margins.left!.unit == Unit.auto);
    assert(margins.right!.unit == Unit.px || margins.right!.unit == Unit.auto);

    Margin marginLeft = margins.left!;
    Margin marginRight = margins.right!;

    bool widthIsAuto = width.unit == Unit.auto;
    bool marginLeftIsAuto = marginLeft.unit == Unit.auto;
    bool marginRightIsAuto = marginRight.unit == Unit.auto;

    if (display == Display.BLOCK) {
      if (childIsReplaced) {
        widthIsAuto = false;
      }

      //If width is not auto and the width of the margin box is larger than the
      // width of the containing block, then consider left and right margins to
      // have a 0 value.
      if (!widthIsAuto) {
        if ((childSize.width + marginLeft.value + marginRight.value) >
            containingBlockSize.width) {
          //Treat auto values of margin left and margin right as 0 for following rules
          marginLeft = Margin(0);
          marginRight = Margin(0);
          marginLeftIsAuto = false;
          marginRightIsAuto = false;
        }
      }

      // If all values are non-auto, the box is overconstrained.
      // One of the margins will need to be ignored.
      if (!widthIsAuto && !marginLeftIsAuto && !marginRightIsAuto) {
        //TODO ignore either left or right margin based on directionality of parent widgets.
        //For now, assume ltr, and just ignore the right margin.
        final difference =
            containingBlockSize.width - childSize.width - marginLeft.value;
        marginRight = Margin(difference);
      }

      // If there is exactly one value specified as auto, compute it value from the equality (our widths are already set)
      if (widthIsAuto && !marginLeftIsAuto && !marginRightIsAuto) {
        widthIsAuto = false;
      } else if (!widthIsAuto && marginLeftIsAuto && !marginRightIsAuto) {
        marginLeft = Margin(
            containingBlockSize.width - childSize.width - marginRight.value);
        marginLeftIsAuto = false;
      } else if (!widthIsAuto && !marginLeftIsAuto && marginRightIsAuto) {
        marginRight = Margin(
            containingBlockSize.width - childSize.width - marginLeft.value);
        marginRightIsAuto = false;
      }

      //If width is set to auto, any other auto values become 0, and width
      // follows from the resulting equality.
      if (widthIsAuto) {
        if (marginLeftIsAuto) {
          marginLeft = Margin(0);
          marginLeftIsAuto = false;
        }
        if (marginRightIsAuto) {
          marginRight = Margin(0);
          marginRightIsAuto = false;
        }
        widthIsAuto = false;
      }

      //If both margin-left and margin-right are auto, their used values are equal.
      // This horizontally centers the element within the containing block.
      if (marginLeftIsAuto && marginRightIsAuto) {
        final newMargin =
            Margin((containingBlockSize.width - childSize.width) / 2);
        marginLeft = newMargin;
        marginRight = newMargin;
        marginLeftIsAuto = false;
        marginRightIsAuto = false;
      }

      //Assert that all auto values have been assigned.
      assert(!marginLeftIsAuto && !marginRightIsAuto && !widthIsAuto);
    }

    return Margins(
        left: marginLeft,
        right: marginRight,
        top: margins.top,
        bottom: margins.bottom);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  void dispose() {
    super.dispose();
  }
}

extension Normalize on Dimension {
  void normalize(double emValue) {
    switch (this.unit) {
      case Unit.em:
        this.value *= emValue;
        this.unit = Unit.px;
        return;
      case Unit.px:
      case Unit.auto:
        return;
    }
  }
}

double _calculateEmValue(Style style, BuildContext buildContext) {
  //TODO is there a better value for this?
  return (style.fontSize?.size ?? 16) *
      MediaQuery.textScaleFactorOf(buildContext) *
      MediaQuery.of(buildContext).devicePixelRatio;
}

class CSSBoxParentData extends ContainerBoxParentData<RenderBox> {}

class _Sizes {
  final Size parentSize;
  final Size childSize;

  const _Sizes(this.parentSize, this.childSize);
}