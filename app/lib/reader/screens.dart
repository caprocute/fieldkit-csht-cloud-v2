import 'package:fk/common_widgets.dart';
import 'package:fk/reader/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flows/flows.dart' as flows;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fk/utils/deep_link_handler.dart';
import '../l10n/app_localizations.dart';

import '../diagnostics.dart';

class MultiScreenFlow extends StatefulWidget {
  final List<String> screenNames;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final bool showProgress;

  const MultiScreenFlow({
    super.key,
    required this.screenNames,
    required this.onComplete,
    required this.onSkip,
    this.showProgress = false,
  });

  @override
  // ignore: library_private_types_in_public_api
  _MultiScreenFlowState createState() => _MultiScreenFlowState();
}

class _MultiScreenFlowState extends State<MultiScreenFlow> {
  int index = 0;

  void onForward() {
    setState(() {
      if (index < widget.screenNames.length - 1) {
        index++;
      } else {
        Loggers.ui.i("complete");
        widget.onComplete();
      }
    });
  }

  void onBack() {
    if (index > 0) {
      Loggers.ui.i("back");
      setState(() {
        index--;
      });
    } else {
      Loggers.ui.i("back:exit");
      Navigator.of(context).pop();
    }
  }

  void onSkip() {
    Loggers.ui.i("skip");
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final flowsContent = context.read<flows.ContentFlows>();

    bool allScreensAvailable = true;
    for (final screenName in widget.screenNames) {
      if (!flowsContent.allScreens.containsKey(screenName)) {
        allScreensAvailable = false;
        break;
      }
    }

    // If screens are missing, automatically load English flows
    if (!allScreensAvailable) {
      Loggers.ui
          .i("Missing screens detected, automatically loading English flows");
      return FutureBuilder<String>(
        future: DefaultAssetBundle.of(context)
            .loadString('resources/flows/flows_en.json'),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final englishFlows = flows.ContentFlows.get(snapshot.data!);
            Loggers.ui.i(
                "English flows loaded successfully, proceeding with English content");
            return _buildWithFlows(englishFlows);
          } else if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(AppLocalizations.of(context)!.error),
              ),
              body: Center(
                child: Text(
                  "Error loading English flows: ${snapshot.error ?? 'Unknown error'}",
                ),
              ),
            );
          } else {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      );
    }

    return _buildWithFlows(flowsContent);
  }

  Widget _buildWithFlows(flows.ContentFlows flowsContent) {
    final screen = flowsContent.getScreen(widget.screenNames[index]);
    double progress = (index + 1) / widget.screenNames.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: AppLocalizations.of(context)!.backButton,
          onPressed: onBack,
        ),
        title: Text(screen.header?.title ?? ""),
        actions: [
          if (screen.guideUrl != null)
            IconButton(
              padding: const EdgeInsets.only(right: 16),
              onPressed: () async {
                navigateToPdfSection(context, screen.guideUrl!);
              },
              icon: SvgPicture.asset(
                'resources/images/icon_product_guide.svg',
                semanticsLabel: screen.guideTitle,
                width: 24,
                height: 24,
              ),
              tooltip: screen.guideTitle,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: widget.showProgress
              ? LinearProgressIndicator(
                  color: Colors.lightBlue,
                  value: progress,
                )
              : const SizedBox.shrink(), // nothing in this case
        ),
      ),
      body: FlowScreenWidget(
        screen: screen,
        onForward: onForward,
        onBack: onBack,
        onSkip: onSkip,
      ),
    );
  }
}

class QuickFlow extends StatefulWidget {
  final flows.StartFlow start;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final bool showProgress;

  const QuickFlow(
      {super.key,
      required this.start,
      required this.onComplete,
      this.onSkip,
      this.showProgress = false});

  @override
  State<QuickFlow> createState() => _QuickFlowState();
}

class _QuickFlowState extends State<QuickFlow> {
  int index = 0;

  void onBack() {
    if (index > 0) {
      Loggers.ui.i("back");
      setState(() {
        index--;
      });
    } else {
      Loggers.ui.i("back:exit");
      Navigator.of(context).pop();
    }
  }

  void onForward() {
    setState(() {
      final flowsContent = context.read<flows.ContentFlows>();
      final screens = flowsContent.getScreens(widget.start);
      final length = screens.length;

      if (index < length - 1) {
        Loggers.ui.i("forward");
        index++;
      } else {
        Loggers.ui.i("forward:exit");
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final flowsContent = context.read<flows.ContentFlows>();
    final screens = flowsContent.getScreens(widget.start);
    final screen = screens[index];
    double progress = (index + 1) / screens.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: AppLocalizations.of(context)!.backButton,
            onPressed:
                onBack, // If onBack is not provided, the IconButton will be disabled.
          ),
          title: Text(screen.header?.title ?? ""),
          actions: [
            if (screen.guideUrl != null)
              IconButton(
                padding: const EdgeInsets.only(right: 16),
                onPressed: () async {
                  navigateToPdfSection(context, screen.guideUrl!);
                },
                icon: SvgPicture.asset(
                  'resources/images/icon_product_guide.svg',
                  semanticsLabel: screen.guideTitle,
                  width: 24,
                  height: 24,
                ),
                tooltip: screen.guideTitle,
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2.0),
            child: widget.showProgress
                ? LinearProgressIndicator(
                    color: Colors.lightBlue,
                    value: progress,
                  )
                : const SizedBox.shrink(), // nothing in this case
          ),
        ),
        body: FlowScreenWidget(
          screen: screen,
          onForward: onForward,
          onBack: onBack,
          onSkip: widget.onSkip ?? widget.onComplete,
        ),
      ),
    );
  }
}

class ProvideContentFlowsWidget extends StatelessWidget {
  final Widget child;
  final bool eager;

  const ProvideContentFlowsWidget({
    super.key,
    required this.child,
    required this.eager,
  });

  @override
  Widget build(BuildContext context) {
    final Locale active = Localizations.localeOf(context);
    final String path = "resources/flows/flows_${active.languageCode}.json";
    Loggers.ui.i("flows:loading $path");
    return FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(path),
        builder: (context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            final flowsContent = flows.ContentFlows.get(snapshot.data!);
            Loggers.ui.i("flows:ready $flowsContent");
            return Provider<flows.ContentFlows>(
              create: (context) => flowsContent,
              dispose: (context, value) => {},
              lazy: false,
              child: child,
            );
          } else {
            if (eager) {
              return child;
            } else {
              return const SizedBox.shrink();
            }
          }
        });
  }
}

class FlowScreenWidget extends StatelessWidget {
  final flows.Screen screen;
  final VoidCallback? onForward;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;

  const FlowScreenWidget({
    super.key,
    required this.screen,
    this.onForward,
    this.onSkip,
    this.onBack,
  });

  List<Widget> buttons() {
    final bool skipAvailable = screen.skip != null;

    return [
      Container(
        margin: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // Forward button
            SizedBox(
              width: double.infinity,
              child: ElevatedTextButton(
                onPressed: onForward,
                text: screen.forward,
              ),
            ),
            // Skip button if available
            if (skipAvailable)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.fromLTRB(80.0, 18.0, 80.0, 18.0),
                ),
                onPressed: onSkip,
                child: Text(
                  screen.skip!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Avenir',
                    fontSize: 15.0,
                    color: Colors.grey[850],
                    letterSpacing: 0.1,
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    assert(screen.simple.length == 1);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                FlowSimpleScreenWidget(screen: screen.simple[0]),
                ...buttons(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FlowSimpleScreenWidget extends StatelessWidget {
  final flows.Simple screen;

  const FlowSimpleScreenWidget({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    return MarkdownWidgetParser(
      logger: Loggers.markDown,
      images: screen.images,
    ).parse(screen.body);
  }
}

class FlowNamedScreenWidget extends StatelessWidget {
  final String name;
  final VoidCallback? onForward;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;

  const FlowNamedScreenWidget({
    super.key,
    required this.name,
    this.onForward,
    this.onSkip,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final flowsContent = context.read<flows.ContentFlows>();
    final screen = flowsContent.getScreen(name);

    return FlowScreenWidget(
      screen: screen,
      onForward: onForward,
      onSkip: onSkip,
      onBack: onBack,
    );
  }
}
