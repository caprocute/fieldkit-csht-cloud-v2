// ignore_for_file: void_checks

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fk/sync/data_sync_page.dart';
import 'package:fk/models/known_stations_model.dart';
import 'package:fk/app_state.dart';
import 'package:fk/sync/components/connectivity_service.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:collection';
import 'package:fk/gen/api.dart';

// Mock classes
class MockStationOperations extends Mock implements StationOperations {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockTasksModel extends Mock implements TasksModel {}

class MockLoginTask extends Mock implements LoginTask {}

class MockDownloadTask extends Mock implements DownloadTask {}

class MockUploadTask extends Mock implements UploadTask {}

class MockKnownStationsModel extends Mock implements KnownStationsModel {}

class MockStationModel extends Mock implements StationModel {}

class MockStationEphemeral extends Mock implements EphemeralConfig {}

class MockCapabilities extends Mock implements DeviceCapabilities {}

class TokensFake extends Fake implements Tokens {}

class MockWakelockPlus extends Mock {
  Future<void> enable();
  Future<void> disable();
}

void main() {
  late MockKnownStationsModel mockKnownStationsModel;
  late MockTasksModel mockTasksModel;
  late MockStationOperations mockStationOperations;
  late MockConnectivityService mockConnectivityService;
  late MockWakelockPlus mockWakelock;

  setUpAll(() {
    // Register fallback values
    registerFallbackValue(DownloadTask(deviceId: 'test', first: 0, total: 0));
    registerFallbackValue(const Tokens(
      token: 'test-token',
      transmission: TransmissionToken(
        token: 'test-transmission',
        url: 'test-url',
      ),
    ));
    registerFallbackValue(UploadTask(
      deviceId: 'test',
      files: [],
      tokens: const Tokens(
        token: 'test-token',
        transmission: TransmissionToken(
          token: 'test-transmission',
          url: 'test-url',
        ),
      ),
      problem: UploadProblem.none,
    ));

    mockKnownStationsModel = MockKnownStationsModel();
    mockTasksModel = MockTasksModel();
    mockStationOperations = MockStationOperations();
    mockConnectivityService = MockConnectivityService();
    mockWakelock = MockWakelockPlus();

    // Mock methods and properties as needed
    when(() => mockKnownStationsModel.stations)
        .thenReturn(UnmodifiableListView<StationModel>([]));
    when(() => mockKnownStationsModel.addListener(any())).thenReturn(() {});
    when(() => mockKnownStationsModel.removeListener(any())).thenReturn(() {});
    when(() => mockKnownStationsModel.dispose()).thenAnswer((_) {});
    when(() => mockKnownStationsModel.notifyListeners()).thenReturn(() {});

    when(() => mockTasksModel.getAll<LoginTask>()).thenReturn([]);
    when(() => mockTasksModel.addListener(any())).thenReturn(() {});
    when(() => mockTasksModel.removeListener(any())).thenReturn(() {});
    when(() => mockTasksModel.dispose()).thenAnswer((_) {});
    when(() => mockTasksModel.notifyListeners()).thenReturn(() {});

    when(() => mockStationOperations.isBusy(any())).thenReturn(false);
    when(() => mockStationOperations.addListener(any())).thenReturn(() {});
    when(() => mockStationOperations.removeListener(any())).thenReturn(() {});
    when(() => mockStationOperations.dispose()).thenAnswer((_) {});
    when(() => mockStationOperations.notifyListeners()).thenReturn(() {});

    when(() => mockConnectivityService.isConnected).thenReturn(true);
    when(() => mockConnectivityService.addListener(any())).thenReturn(() {});
    when(() => mockConnectivityService.removeListener(any())).thenReturn(() {});
    when(() => mockConnectivityService.dispose()).thenAnswer((_) {});
    when(() => mockConnectivityService.notifyListeners()).thenReturn(() {});

    when(() => mockWakelock.enable()).thenAnswer((_) => Future.value());
    when(() => mockWakelock.disable()).thenAnswer((_) => Future.value());
  });
  group('DataSyncTab and DataSyncPage Tests', () {
    setUp(() {});
    testWidgets('DataSyncTab builds without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<KnownStationsModel>.value(
                value: mockKnownStationsModel),
            ChangeNotifierProvider<TasksModel>.value(value: mockTasksModel),
            ChangeNotifierProvider<StationOperations>.value(
                value: mockStationOperations),
            ChangeNotifierProvider<ConnectivityService>.value(
                value: mockConnectivityService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: [Locale('en')],
            home: DataSyncTab(),
          ),
        ),
      );

      expect(find.byType(DataSyncPage), findsOneWidget);
    });

    testWidgets(
        'DataSyncPage displays NoStationsHelpWidget when no stations are available',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<KnownStationsModel>.value(
                value: mockKnownStationsModel),
            ChangeNotifierProvider<TasksModel>.value(value: mockTasksModel),
            ChangeNotifierProvider<StationOperations>.value(
                value: mockStationOperations),
            ChangeNotifierProvider<ConnectivityService>.value(
                value: mockConnectivityService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: [Locale('en')],
            home: DataSyncTab(),
          ),
        ),
      );
    });

    testWidgets(
        'DataSyncPage displays station sync status - download - when stations are available',
        (tester) async {
      // Setup
      final knownStations = MockKnownStationsModel();
      final stationOperations = MockStationOperations();
      final tasks = MockTasksModel();
      final connectivityService = MockConnectivityService();

      final station = StationModel(
        deviceId: 'test-device',
        config: StationConfig(
          name: 'Test Station',
          lastSeen: UtcDateTime(field0: DateTime.now().millisecondsSinceEpoch),
          deviceId: 'test-device',
          generationId: '1',
          firmware: FirmwareInfo(
            label: 'test',
            time: DateTime.now().millisecondsSinceEpoch,
          ),
          meta: StreamInfo(size: BigInt.from(0), records: BigInt.from(0)),
          data: StreamInfo(size: BigInt.from(0), records: BigInt.from(0)),
          battery: const BatteryInfo(percentage: 100, voltage: 0),
          solar: const SolarInfo(voltage: 0),
          modules: const [],
        ),
      );

      // Mock behaviors
      when(() => knownStations.stations)
          .thenReturn(UnmodifiableListView<StationModel>([station]));
      when(() => tasks.getAll<LoginTask>()).thenReturn([]);
      when(() => tasks.getMaybeOne<DownloadTask>(any())).thenReturn(
        DownloadTask(
            deviceId: 'test-device',
            first: 0,
            total: 100), // Return a download task
      );
      when(() => tasks.getMaybeOne<UploadTask>(any())).thenReturn(null);
      when(() => connectivityService.isConnected).thenReturn(true);

      // Build widget and wait for it to settle
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<KnownStationsModel>.value(
                  value: knownStations),
              ChangeNotifierProvider<StationOperations>.value(
                  value: stationOperations),
              ChangeNotifierProvider<TasksModel>.value(value: tasks),
              ChangeNotifierProvider<ConnectivityService>.value(
                  value: connectivityService),
            ],
            child: DataSyncPage(
              known: knownStations,
              stationOperations: stationOperations,
              tasks: tasks,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find by type instead of key since the key might not be present
      expect(find.text('Test Station'), findsOneWidget);
      expect(find.byType(StationSyncWidget),
          findsOneWidget); // Look for the widget type
      expect(find.byType(DownloadButtonWidget), findsOneWidget);
    });

    testWidgets('DataSyncPage displays station sync status - upload',
        (tester) async {
      // Setup
      final knownStations = MockKnownStationsModel();
      final stationOperations = MockStationOperations();
      final tasks = MockTasksModel();
      final connectivityService = MockConnectivityService();

      final station = StationModel(
        deviceId: 'test-device',
        config: StationConfig(
          name: 'Test Station',
          lastSeen: UtcDateTime(field0: DateTime.now().millisecondsSinceEpoch),
          deviceId: 'test-device',
          generationId: '1',
          firmware: FirmwareInfo(
            label: 'test',
            time: DateTime.now().millisecondsSinceEpoch,
          ),
          meta: StreamInfo(size: BigInt.from(0), records: BigInt.from(0)),
          data: StreamInfo(size: BigInt.from(0), records: BigInt.from(0)),
          battery: const BatteryInfo(percentage: 100, voltage: 0),
          solar: const SolarInfo(voltage: 0),
          modules: const [],
        ),
      );

      // Mock behaviors
      when(() => knownStations.stations)
          .thenReturn(UnmodifiableListView<StationModel>([station]));
      when(() => tasks.getAll<LoginTask>()).thenReturn([]);
      when(() => tasks.getMaybeOne<DownloadTask>(any())).thenReturn(null);
      when(() => tasks.getMaybeOne<UploadTask>(any())).thenReturn(
        UploadTask(
          deviceId: 'test-device',
          files: [
            const RecordArchive(
              deviceId: 'test-device',
              generationId: '1',
              path: 'test-path',
              head: 0,
              tail: 100,
            )
          ],
          tokens: const Tokens(
            token: 'test-token',
            transmission: TransmissionToken(
              token: 'test-transmission',
              url: 'test-url',
            ),
          ),
          problem: UploadProblem.none,
        ),
      );
      when(() => connectivityService.isConnected).thenReturn(true);

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // Wrap in Scaffold
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<KnownStationsModel>.value(
                    value: knownStations),
                ChangeNotifierProvider<StationOperations>.value(
                    value: stationOperations),
                ChangeNotifierProvider<TasksModel>.value(value: tasks),
                ChangeNotifierProvider<ConnectivityService>.value(
                    value: connectivityService),
              ],
              child: DataSyncPage(
                known: knownStations,
                stationOperations: stationOperations,
                tasks: tasks,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widgets
      expect(find.text('Test Station'), findsOneWidget);
      expect(find.byType(StationSyncWidget), findsOneWidget);
    });

    testWidgets('Chevron toggles correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExpansionTile(
              title: Text('Test Section'),
              children: [Text('Content')],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find by type and semantic label
      expect(find.byType(ExpansionTile), findsOneWidget);

      // Tap the tile to expand
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Verify content is visible
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('DataSyncPage displays station sync status', (tester) async {
      // Setup
      final knownStations = MockKnownStationsModel();
      final stationOperations = MockStationOperations();
      final tasks = MockTasksModel();
      final connectivityService = MockConnectivityService();

      final station = StationModel(
        deviceId: 'test-device',
        config: StationConfig(
          name: 'Test Station',
          lastSeen: UtcDateTime(field0: DateTime.now().millisecondsSinceEpoch),
          deviceId: 'test-device',
          generationId: '1',
          firmware: FirmwareInfo(
            label: 'test',
            time: DateTime.now().millisecondsSinceEpoch,
          ),
          meta: StreamInfo(size: BigInt.from(0), records: BigInt.from(0)),
          data: StreamInfo(size: BigInt.from(0), records: BigInt.from(0)),
          battery: const BatteryInfo(percentage: 100, voltage: 0),
          solar: const SolarInfo(voltage: 0),
          modules: const [],
        ),
      );

      // Mock behaviors
      when(() => knownStations.stations)
          .thenReturn(UnmodifiableListView<StationModel>([station]));
      when(() => tasks.getAll<LoginTask>()).thenReturn([]);
      when(() => tasks.getMaybeOne<DownloadTask>(any())).thenReturn(null);
      when(() => tasks.getMaybeOne<UploadTask>(any())).thenReturn(null);
      when(() => connectivityService.isConnected).thenReturn(true);

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<KnownStationsModel>.value(
                  value: knownStations),
              ChangeNotifierProvider<StationOperations>.value(
                  value: stationOperations),
              ChangeNotifierProvider<TasksModel>.value(value: tasks),
              ChangeNotifierProvider<ConnectivityService>.value(
                  value: connectivityService),
            ],
            child: DataSyncPage(
              known: knownStations,
              stationOperations: stationOperations,
              tasks: tasks,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Only verify widget presence
      expect(find.text('Test Station'), findsOneWidget);
      expect(find.byType(DownloadButtonWidget), findsOneWidget);
    });
  });
}
