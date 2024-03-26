import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/src/navigation_delegate.dart';
import 'package:flutter_html/src/replaced_element.dart';
import 'package:flutter_html/style.dart';
import 'package:html/dom.dart' as dom;
import 'package:webview_flutter/webview_flutter.dart' as webview;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// [IframeContentElement is a [ReplacedElement] with web content.
class IframeContentElement extends ReplacedElement {
  final String? src;
  final double? width;
  final double? height;
  final NavigationDelegate? navigationDelegate;
  final UniqueKey key = UniqueKey();

  IframeContentElement({
    required String name,
    required this.src,
    required this.width,
    required this.height,
    required dom.Element node,
    required this.navigationDelegate,
  }) : super(name: name, style: Style(), node: node, elementId: node.id);

  @override
  Widget toWidget(RenderContext context) {
    return SizedBox(
      width: width ?? (height ?? 150) * 2,
      height: height ?? (width ?? 300) / 2,
      child: ContainerSpan(
        style: context.style,
        newContext: context,
        child: _WebViewWidget(
          src: src,
          navigationDelegate: navigationDelegate,
          attributes: attributes,
        ),
      ),
    );
  }
}

class _WebViewWidget extends StatefulWidget {
  const _WebViewWidget({
    Key? key,
    this.src,
    required this.attributes,
    required this.navigationDelegate,
  }) : super(key: key);

  final String? src;
  final Map<String, String> attributes;
  final NavigationDelegate? navigationDelegate;

  @override
  State<_WebViewWidget> createState() => _WebViewWidgetState();
}

class _WebViewWidgetState extends State<_WebViewWidget> {
  late final webview.WebViewController controller;
  late final webview.PlatformWebViewControllerCreationParams params;
  final UniqueKey key = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (webview.WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const webview.PlatformWebViewControllerCreationParams();
    }

    controller = webview.WebViewController.fromPlatformCreationParams(params);

    final sandboxMode = widget.attributes["sandbox"];

    controller
        .setJavaScriptMode(
      sandboxMode == null || sandboxMode == "allow-scripts"
          ? webview.JavaScriptMode.unrestricted
          : webview.JavaScriptMode.disabled,
    )
        .then((value) {
      controller.setNavigationDelegate(
        webview.NavigationDelegate(
          onNavigationRequest: (request) async {
            final result =
                await widget.navigationDelegate?.call(NavigationRequest(
              url: request.url,
              isForMainFrame: request.isMainFrame,
            ));
            if (result == NavigationDecision.prevent) {
              return webview.NavigationDecision.prevent;
            } else {
              return webview.NavigationDecision.navigate;
            }
          },
        ),
      ).then(
        (value) {
          if (widget.src != null) {
            controller.loadRequest(Uri.parse(widget.src!));
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return webview.WebViewWidget(
      controller: controller,
      key: key,
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer())
      },
    );
  }
}
