import 'package:collection/collection.dart';
import 'package:fk/constants.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';

Widget dismissKeyboardOnOutsideGap(Widget body) {
  return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(), child: body);
}

class BorderedListItem extends StatelessWidget {
  final GenericListItemHeader header;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const BorderedListItem(
      {super.key, required this.header, required this.children, this.margin});

  @override
  Widget build(BuildContext context) {
    return Card(
        margin: margin ?? const EdgeInsets.all(16),
        shadowColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(color: Colors.grey.shade300, width: 1)),
        child: Column(children: [header, ...children]));
  }
}

class ExpandableBorderedListItem extends StatefulWidget {
  final GenericListItemHeader header;
  final List<Widget> children;
  final bool expanded;
  final EdgeInsetsGeometry? margin;

  const ExpandableBorderedListItem(
      {super.key,
      required this.header,
      required this.children,
      required this.expanded,
      this.margin});

  @override
  State<StatefulWidget> createState() => _ExpandableBorderedListItemState();
}

class _ExpandableBorderedListItemState
    extends State<ExpandableBorderedListItem> {
  bool? _expanded;

  bool get expanded => _expanded ?? widget.expanded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          setState(() {
            _expanded = !expanded;
          });
        },
        child: BorderedListItem(
            header: widget.header,
            margin: widget.margin ?? const EdgeInsets.all(16),
            children: [if (expanded) ...widget.children]));
  }
}

class GenericListItemHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Icon? trailing;
  final VoidCallback? onTap;

  const GenericListItemHeader(
      {super.key,
      required this.title,
      this.subtitle,
      this.titleStyle,
      this.subtitleStyle,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final top = WH.align(WH.padPage(Row(children: [
      Expanded(
        child: Text(title,
            style: titleStyle ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.normal)),
      ),
      if (trailing != null) trailing!,
    ])));

    if (subtitle == null) {
      return top;
    }

    final bottom = WH.align(WH.padPage(Text(subtitle!, style: subtitleStyle)));

    return Column(children: [top, bottom]);
  }
}

class WH {
  static const pagePadding = EdgeInsets.fromLTRB(14, 14, 14, 14);

  static List<Widget> divideWith(
      Widget Function() divider, List<Widget> widgets) {
    return widgets.map((el) => [el, divider()]).flattened.toList();
  }

  static Align align(Widget child) =>
      Align(alignment: Alignment.topLeft, child: child);

  static Padding around(Widget child) =>
      Padding(padding: pagePadding, child: child);

  static Padding vertical(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: child);

  static Container padPage(Widget child) =>
      Container(padding: pagePadding, child: child);

  static List<Widget> padButtonsRow(List<Widget> children) => children
      .map((c) => Padding(padding: const EdgeInsets.only(right: 10), child: c))
      .toList();

  static Container padChildrenPage(List<Widget> children) =>
      Container(padding: pagePadding, child: Column(children: children));

  static Padding padLabel(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: child);

  static Padding padColumn(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child);

  static Padding padBelowProgress(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: child);

  static LinearProgressIndicator progressBar(double value) =>
      LinearProgressIndicator(value: value);

  static TextStyle buttonStyle(double size) => TextStyle(
        fontFamily: 'Avenir',
        fontSize: size,
        fontWeight: FontWeight.w500,
      );

  static TextStyle monoStyle(double size) => TextStyle(
      fontSize: size,
      fontFamily: "monospace",
      fontFamilyFallback: const ["Courier"]);
}

class OopsBug extends StatelessWidget {
  const OopsBug({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(AppLocalizations.of(context)!.oopsBugTitle);
  }
}

class OutlinedTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;

  const OutlinedTextButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2.0),
        ),
        side: const BorderSide(color: AppColors.primaryColor),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: AppColors.primaryColor,
            fontFamily: "Avenir",
            fontSize: 16.0,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ElevatedTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonStyle? style;

  const ElevatedTextButton(
      {super.key, required this.text, required, this.onPressed, this.style});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Avenir',
            fontSize: 16.0,
          ),
        ));
  }
}

class ConnectedStatusIcon extends StatelessWidget {
  final bool connected;
  final colorFilter =
      const ColorFilter.mode(Color(0xFFcccdcf), BlendMode.srcIn);

  const ConnectedStatusIcon({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final icon = SizedBox(
      width: 54.0,
      height: 54.0,
      child: connected
          ? SvgPicture.asset(
              AppIcons.stationConnected,
              semanticsLabel: localizations.stationConnectedIcon,
            )
          : SvgPicture.asset(
              AppIcons.stationDisconnected,
              semanticsLabel: localizations.stationDisconnectedIcon,
              colorFilter: colorFilter,
            ),
    );

    return icon;
  }
}
