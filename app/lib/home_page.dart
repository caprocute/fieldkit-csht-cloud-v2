import 'package:fk/diagnostics.dart';
import 'package:fk/preferences.dart';
import 'package:fk/settings/help_page.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'my_stations_page.dart';
import 'settings/settings_page.dart';
import 'sync/data_sync_page.dart';
import 'welcome.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

final GlobalKey<NavigatorState> stationsNavigatorKey = GlobalKey();
final GlobalKey<NavigatorState> dataNavigatorKey = GlobalKey();
final GlobalKey<NavigatorState> settingsNavigatorKey = GlobalKey();
final GlobalKey<NavigatorState> helpNavigatorKey = GlobalKey();

class _HomePageState extends State<HomePage> {
  int _pageIndex = 0;
  bool _showWelcome = true;
  int _openCount = 0;
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    final appPrefs = AppPreferences();
    _openCount = await appPrefs.getOpenCount() ?? 0;
    await _checkIfFirstTimeToday();
  }

  Future<void> _checkIfFirstTimeToday() async {
    final appPrefs = AppPreferences();
    DateTime today = DateTime.now();
    DateTime? lastOpened = await appPrefs.getLastOpened();
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _openCount++;
    });

    if (lastOpened == null ||
        lastOpened.day != today.day ||
        lastOpened.month != today.month ||
        lastOpened.year != today.year) {
      await appPrefs.setLastOpened(today);
      if (_openCount < 3) {
        setState(() {
          _showWelcome = true;
        });
        await prefs.setBool('showWelcome', true);
      } else {
        setState(() {
          _showWelcome = false;
        });
        await prefs.setBool('showWelcome', false);
      }
    } else {
      setState(() {
        _showWelcome = prefs.getBool('showWelcome') ?? false;
      });
    }
    Loggers.ui.i('showWelcome: $_showWelcome');
  }

  void setPageIndex(int index) {
    setState(() {
      _pageIndex = index;
    });
  }

  void _resetNavigator(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (index) {
        case 0:
          if (stationsNavigatorKey.currentState?.canPop() ?? false) {
            stationsNavigatorKey.currentState
                ?.popUntil((route) => route.isFirst);
          }
          break;
        case 1:
          if (dataNavigatorKey.currentState?.canPop() ?? false) {
            dataNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
          break;
        case 2:
          if (settingsNavigatorKey.currentState?.canPop() ?? false) {
            settingsNavigatorKey.currentState
                ?.popUntil((route) => route.isFirst);
          }
          break;
        case 3:
          if (helpNavigatorKey.currentState?.canPop() ?? false) {
            helpNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.connectionState == ConnectionState.done) {
            return SafeArea(
                child: ProvideEverythingWidget(
              child: _showWelcome
                  ? WelcomeScreen(
                      onDone: () async {
                        setState(() {
                          _showWelcome = false;
                        });
                        final appPrefs = AppPreferences();
                        await appPrefs.setOpenCount(_openCount);
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('showWelcome', false);
                      },
                    )
                  : IndexedStack(
                      index: _pageIndex,
                      children: <Widget>[
                        Navigator(
                          key: stationsNavigatorKey,
                          onGenerateRoute: (RouteSettings settings) {
                            return MaterialPageRoute(
                                settings: settings,
                                builder: (context) => const StationsTab());
                          },
                        ),
                        Navigator(
                          key: dataNavigatorKey,
                          onGenerateRoute: (RouteSettings settings) {
                            return MaterialPageRoute(
                                settings: settings,
                                builder: (context) => const DataSyncTab());
                          },
                        ),
                        Navigator(
                          key: settingsNavigatorKey,
                          onGenerateRoute: (RouteSettings settings) {
                            return MaterialPageRoute(
                                settings: settings,
                                builder: (BuildContext context) {
                                  return const SettingsTab();
                                });
                          },
                        ),
                        Navigator(
                          key: helpNavigatorKey,
                          onGenerateRoute: (RouteSettings settings) {
                            return MaterialPageRoute(
                                settings: settings,
                                builder: (BuildContext context) {
                                  return const HelpTab();
                                });
                          },
                        ),
                      ],
                    ),
            ));
          } else {
            return Center(
                child: Text(AppLocalizations.of(context)!.errorStartingApp));
          }
        },
      ),
      bottomNavigationBar: _showWelcome
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF2C3E50),
              unselectedLabelStyle: const TextStyle(fontSize: 12.0),
              selectedLabelStyle:
                  const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w700),
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Semantics(
                    label: AppLocalizations.of(context)!.stationsTab,
                    child: Image.asset(
                        'resources/images/icon_station_inactive.png',
                        width: 24,
                        height: 24),
                  ),
                  activeIcon: Semantics(
                    label: AppLocalizations.of(context)!.stationsTab,
                    child: Image.asset(
                        'resources/images/icon_station_active.png',
                        width: 24,
                        height: 24),
                  ),
                  label: AppLocalizations.of(context)!.stationsTab,
                ),
                BottomNavigationBarItem(
                  icon: Semantics(
                    label: AppLocalizations.of(context)!.dataSyncTab,
                    child: Image.asset(
                        'resources/images/icon_data_sync_inactive.png',
                        width: 24,
                        height: 24),
                  ),
                  activeIcon: Semantics(
                    label: AppLocalizations.of(context)!.dataSyncTab,
                    child: Image.asset(
                        'resources/images/icon_data_sync_active.png',
                        width: 24,
                        height: 24),
                  ),
                  label: AppLocalizations.of(context)!.dataSyncTab,
                ),
                BottomNavigationBarItem(
                  icon: Semantics(
                    label: AppLocalizations.of(context)!.settingsTab,
                    child: Image.asset(
                        'resources/images/icon_settings_inactive.png',
                        width: 24,
                        height: 24),
                  ),
                  activeIcon: Semantics(
                    label: AppLocalizations.of(context)!.settingsTab,
                    child: Image.asset(
                        'resources/images/icon_settings_active.png',
                        width: 24,
                        height: 24),
                  ),
                  label: AppLocalizations.of(context)!.settingsTab,
                ),
                BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                      "resources/images/icon_help_settings.svg",
                      semanticsLabel: AppLocalizations.of(context)!
                          .helpSettingsIconInactive,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF9a9fa6), BlendMode.srcIn)),
                  activeIcon: SvgPicture.asset(
                      "resources/images/icon_help_settings.svg",
                      semanticsLabel:
                          AppLocalizations.of(context)!.helpSettingsIconActive,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF2c3e50), BlendMode.srcIn)),
                  label: AppLocalizations.of(context)!.helpTab,
                ),
              ],
              currentIndex: _pageIndex,
              onTap: (int index) {
                if (index == _pageIndex) {
                  _resetNavigator(index);
                } else {
                  setPageIndex(index);
                }
              },
            ),
    );
  }
}

class ProvideEverythingWidget extends StatelessWidget {
  final Widget child;

  const ProvideEverythingWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
            value: context.read<AppState>().connectivityService),
        ChangeNotifierProvider.value(
            value: context.read<AppState>().moduleConfigurations),
        ChangeNotifierProvider.value(
            value: context.read<AppState>().knownStations),
        ChangeNotifierProvider.value(value: context.read<AppState>().firmware),
        ChangeNotifierProvider.value(
            value: context.read<AppState>().stationOperations),
        ChangeNotifierProvider.value(value: context.read<AppState>().tasks),
      ],
      child: child,
    );
  }
}
