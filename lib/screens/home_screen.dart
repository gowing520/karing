// ignore_for_file: prefer_interpolation_to_compose_strings, use_build_context_synchronously, empty_catches, unused_catch_stack

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inapp_notifications/flutter_inapp_notifications.dart';
import 'package:karing/app/local_services/vpn_service.dart';
import 'package:karing/app/modules/app_lifecycle_state_notify_manager.dart';
//import 'package:animated_toggle_switch/animated_toggle_switch.dart';

import 'package:karing/app/modules/auto_update_manager.dart';
import 'package:karing/app/modules/biz.dart';
import 'package:karing/app/modules/notice_manager.dart';
import 'package:karing/app/modules/proxy_cluster.dart';
import 'package:karing/app/modules/remote_config_manager.dart';
import 'package:karing/app/modules/server_manager.dart';
import 'package:karing/app/modules/setting_manager.dart';
import 'package:karing/app/modules/yacd.dart';
import 'package:karing/app/runtime/return_result.dart';
import 'package:karing/app/utils/analytics_utils.dart';
import 'package:karing/app/utils/clash_api.dart';
import 'package:karing/app/utils/diversion_custom_utils.dart';
import 'package:karing/app/utils/error_reporter_utils.dart';
import 'package:karing/app/utils/file_utils.dart';
import 'package:karing/app/utils/http_utils.dart';
import 'package:karing/app/utils/local_notifications_utils.dart';
import 'package:karing/app/utils/local_storeage.dart';
import 'package:karing/app/utils/log.dart';
import 'package:karing/app/utils/main_channel_utils.dart';
import 'package:karing/app/utils/path_utils.dart';
import 'package:karing/app/utils/platform_utils.dart';
import 'package:karing/app/utils/proxy_conf_utils.dart';
import 'package:karing/app/utils/singbox_config_builder.dart';
import 'package:karing/app/utils/system_scheme_utils.dart';
import 'package:karing/app/utils/url_launcher_utils.dart';
import 'package:karing/i18n/strings.g.dart';
import 'package:karing/screens/common_dialog.dart';
import 'package:karing/screens/common_widget.dart';
import 'package:karing/screens/dialog_utils.dart';
import 'package:karing/screens/diversion_rules_custom_set_screen.dart';
import 'package:karing/screens/group_helper.dart';
import 'package:karing/screens/language_settings_screen.dart';
import 'package:karing/screens/my_profiles_screen.dart';
import 'package:karing/screens/net_check_screen.dart';
import 'package:karing/screens/net_connections_screen.dart';
import 'package:karing/screens/novice_screen.dart';
import 'package:karing/screens/region_settings_screen.dart';
import 'package:karing/screens/richtext_viewer.screen.dart';
import 'package:karing/screens/scheme_handler.dart';
import 'package:karing/screens/server_select_screen.dart';
import 'package:karing/screens/settings_screen.dart';
import 'package:karing/screens/theme_config.dart';
import 'package:karing/screens/theme_data_blue.dart';
import 'package:karing/screens/theme_data_dark.dart';
import 'package:karing/screens/theme_data_light.dart';
import 'package:karing/screens/theme_define.dart';
import 'package:karing/screens/themes.dart';
import 'package:karing/screens/user_agreement_screen.dart';
import 'package:karing/screens/version_update_screen.dart';
import 'package:karing/screens/webview_helper.dart';
import 'package:karing/screens/widgets/ads_banner_widget.dart';
import 'package:karing/screens/widgets/framework.dart';
import 'package:karing/screens/widgets/segmented_button.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:path/path.dart' as path;
import 'package:protocol_handler/protocol_handler.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:vpn_service/state.dart';
import 'package:web_socket_channel/io.dart';
import 'package:window_manager/window_manager.dart';

class Header {
  String tooltip = "";
  IconData? iconData;
  VoidCallback? onTap;
  FocusNode focus;
  Header(this.tooltip, this.iconData, this.onTap, this.focus);
}

class HomeScreen extends LasyRenderingStatefulWidget {
  static RouteSettings routSettings() {
    return const RouteSettings(name: "/");
  }

  final String launchUrl; // await protocolHandler.getInitialUrl();
  const HomeScreen({super.key, required this.launchUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends LasyRenderingState<HomeScreen>
    with WidgetsBindingObserver, ProtocolListener, AfterLayoutMixin {
  static const double kMaxWidth = 500;
  static const int kLocalNotificationsIdVpnStateId = 1;
  static const int kLocalNotificationsIdNetStateId = 2;

  static const String kLocalNotificationsIdNetState = "netState";
  static const String kLocalNotificationsIdVpnState = "vpnState";
  final FocusNode _focusNodeSettings = FocusNode();
  final FocusNode _focusNodeTheme = FocusNode();
  final FocusNode _focusNodeSwitch = FocusNode();
  final FocusNode _focusNodeSelect = FocusNode();

  final FocusNode _focusNodeSystemProxyTips = FocusNode();
  final FocusNode _focusNodeSystemProxy = FocusNode();
  final FocusNode _focusNodeRule = FocusNode();
  final FocusNode _focusNodeGlobal = FocusNode();
  final FocusNode _focusNodeConnections = FocusNode();

  final FocusNode _focusNodeMyProfiles = FocusNode();
  final FocusNode _focusNodeAddProfile = FocusNode();
  final FocusNode _focusNodeDNS = FocusNode();
  final FocusNode _focusNodeDeversion = FocusNode();
  final FocusNode _focusNodeNetcheck = FocusNode();
  final FocusNode _focusNodeSpeedtest = FocusNode();
  final FocusNode _focusNodeMyLink = FocusNode();
  final FocusNode _focusNodeAppleTV = FocusNode();
  final FocusNode _focusNodeMore = FocusNode();
  final List<FocusNode> _focusNodeToolbar = [];

  HttpClient? _httpClient;
  StreamSubscription<dynamic>? _subscriptions;
  bool _wsConnecting = false;

  final ValueNotifier<String> _trafficUpTotal = ValueNotifier<String>("0 B");
  final ValueNotifier<String> _trafficDownTotal = ValueNotifier<String>("0 B");
  final ValueNotifier<String> _trafficUpTotalProxy =
      ValueNotifier<String>("0 B");
  final ValueNotifier<String> _trafficDownTotalProxy =
      ValueNotifier<String>("0 B");
  final ValueNotifier<String> _trafficUpSpeed = ValueNotifier<String>("0 B/s");
  final ValueNotifier<String> _trafficDownSpeed =
      ValueNotifier<String>("0 B/s");
  final ValueNotifier<String> _startDuration = ValueNotifier<String>("0:00:00");
  final ValueNotifier<String> _memory = ValueNotifier<String>("0 B");
  final ValueNotifier<String> _connInboundCount = ValueNotifier<String>("");

  String _trafficUpTotalNotify = "0 B";
  String _trafficDownTotalNotify = "0 B";
  String _trafficUpTotalProxyNotify = "0 B";
  String _trafficDownTotalProxyNotify = "0 B";
  String _trafficUpSpeedNotify = "0 B/s";
  String _trafficDownSpeedNotify = "0 B/s";
  String _startDurationNotify = "0 B/s";

  bool _isStarting = false;
  bool _isStarted = false;
  bool _isStoping = false;
  bool _isSystemProxySet = false;

  bool _canConnect = false;
  Timer? _timer;
  Timer? _wstimer;
  CurrentServerForSelector _currentServerForSelector =
      CurrentServerForSelector();

  ProxyConfig _currentServer = ProxyConfig();
  bool _inAppNotificationsShowing = false;
  bool _onInitAllFinished = false;
  String _initUrl = "";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    protocolHandler.addListener(this);
    _initUrl = widget.launchUrl;
    _init();
    LocalNotifications.init();
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    Biz.initHomeFinish();
    ErrorReporterUtils.register(() {
      if (!mounted) {
        return;
      }
      final tcontext = Translations.of(context);
      DialogUtils.showAlertDialog(context, tcontext.HomeScreen.deviceNoSpace,
          showCopy: true, showFAQ: true, withVersion: true);
    });

    Future.delayed(const Duration(seconds: 0), () async {
      showAgreement();
    });
    if (PlatformUtils.maybeTV()) {
      _focusNodeSettings.requestFocus();
    }
  }

  Future<bool> futureBool(bool value) async {
    return value;
  }

  void showAgreement() async {
    const String idKey = 'userAgreementAgreedKey';
    String? value;
    try {
      value = await LocalStorage.read(idKey);
    } catch (e) {
      DialogUtils.showAlertDialog(context, e.toString(),
          showCopy: true, showFAQ: true, withVersion: true);
      return;
    }

    if (value == null) {
      var tcontext = Translations.of(context);
      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: UserAgreementScreen.routSettings(),
              fullscreenDialog: true,
              builder: (context) => const UserAgreementScreen()));

      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: LanguageSettingsScreen.routSettings(),
              fullscreenDialog: true,
              builder: (context) => LanguageSettingsScreen(
                    canPop: false,
                    canGoBack: false,
                    nextText: () {
                      var tcontext = Translations.of(context);
                      return tcontext.next;
                    },
                  )));
      tcontext = Translations.of(context);

      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: RegionSettingsScreen.routSettings(),
              fullscreenDialog: true,
              builder: (context) => RegionSettingsScreen(
                    canPop: false,
                    canGoBack: false,
                    nextText: tcontext.next,
                  )));

      var settingConfig = SettingManager.getConfig();
      var regionCode = settingConfig.regionCode.toLowerCase();

      DiversionCustomRules rules =
          (await DiversionCustomRulesPreset.getPreset(regionCode)) ??
              DiversionCustomRules();

      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: DiversionRulesCustomSetScreen.routSettings(),
              fullscreenDialog: true,
              builder: (context) => DiversionRulesCustomSetScreen(
                    canPop: false,
                    title: tcontext.diversionCustomGroupPreset,
                    canGoBack: false,
                    nextText: tcontext.next,
                    nextIcon: null,
                    rules: rules,
                  )));

      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: NoviceScreen.routSettings(),
              fullscreenDialog: true,
              builder: (context) => const NoviceScreen()));

      LocalStorage.write(idKey, "true");
      bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
      if (noConfig) {
        onTapAddProfileByAgreement();
      }
      if (PlatformUtils.isPC()) {
        var remoteConfig = RemoteConfigManager.getConfig();
        String url = await UrlLauncherUtils.reorganizationUrlWithAnchor(
            remoteConfig.tutorial);
        if (!context.mounted) {
          return;
        }
        await WebviewHelper.loadUrl(context, url,
            title: tcontext.SettingsScreen.tutorial);
      }
    } else {
      String? installer = await AutoUpdateManager.checkReplace();
      if (installer != null) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                settings: VersionUpdateScreen.routSettings(),
                fullscreenDialog: true,
                builder: (context) => const VersionUpdateScreen(
                      force: true,
                    )));
      }
    }
  }

  void checkError(String from, {bool showAlert = true}) async {
    String errorPath = await PathUtils.serviceStdErrorFilePath();
    String? content = await FileUtils.readAndDelete(errorPath);
    if (content != null && content.isNotEmpty) {
      if (!content.contains("Config expired, Please start from app")) {
        const int maxLength = 5000;
        AnalyticsUtils.logEvent(
            analyticsEventType: analyticsEventTypeApp,
            name: 'HSS_checkError',
            parameters: {
              "err": content.length > maxLength
                  ? content.substring(0, maxLength)
                  : content,
              "from": from,
            });
        if (showAlert) {
          await DialogUtils.showAlertDialog(context, content,
              showCopy: true, showFAQ: true, withVersion: true);
        }
      }
    }
  }

  void updateTile() {
    //MainChannel.call("tile.update", {"started": _isStarting || _isStarted});
  }
  void _startCheckTimer() {
    const Duration duration = Duration(seconds: 1);
    _timer ??= Timer.periodic(duration, (timer) async {
      if (!_isStarting && !_isStoping) {
        if (AppLifecycleStateNofityManager.isPaused()) {
          return;
        }
        bool started = await VPNService.started();
        if (started != _isStarted) {
          _isStarted = started;
          Biz.vpnStateChanged(_isStarted);
          setState(() {});
        }
        if (!_isStarted) {
          _canConnect = false;
        }
        updateTile();

        if (_canConnect) {
          _connectToCurrent();
          _connectToService();
        } else {
          _disconnectToCurrent();
          _disconnectToService();
        }
      }
      if (PlatformUtils.isPC()) {
        bool systemProxyset = await VPNService.getSystemProxy();
        if (systemProxyset != _isSystemProxySet) {
          _isSystemProxySet = systemProxyset;
          setState(() {});
        }
      }
    });
  }

  void _stopCheckTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _connectToCurrent() async {
    if (_currentServer.groupid != ServerManager.getUrltestGroupId()) {
      return;
    }

    bool started = await VPNService.started();
    if (!started) {
      String now = _currentServerForSelector.now;
      int delay = _currentServerForSelector.history.delay;
      _currentServerForSelector.clear();
      if (_currentServerForSelector.now != now ||
          _currentServerForSelector.history.delay != delay) {
        setState(() {});
      }
      return;
    }
    if (_wstimer != null) {
      return;
    }
    //Log.w("_connectToCurrent");
    _wstimer ??= Timer.periodic(const Duration(seconds: 3), (timer) async {
      bool started = await VPNService.started();
      if (!started) {
        if (_currentServerForSelector.now.isNotEmpty ||
            _currentServerForSelector.history.delay != 0) {
          _currentServerForSelector.clear();
          setState(() {});
        }

        return;
      }
      ReturnResult<CurrentServerForSelector> result =
          await ClashApi.getCurrentServerForUrltest(
              ServerManager.getUrltestTagForCustom(_currentServer.tag),
              SettingManager.getConfig().proxy.controlPort);
      String now = _currentServerForSelector.now;
      int delay = _currentServerForSelector.history.delay;
      if (result.error != null) {
        _currentServerForSelector.clear();
      } else {
        _currentServerForSelector = result.data!;
        _currentServer.latency = _currentServerForSelector.history.delay > 0
            ? _currentServerForSelector.history.delay.toString()
            : _currentServerForSelector.history.error;

        ProxyConfig? proxy =
            ServerManager.getConfig().getByTag(_currentServerForSelector.now);
        if (proxy != null) {
          proxy.latency = _currentServer.latency;
        }
        if (_currentServer.groupid == ServerManager.getUrltestGroupId() &&
            _currentServer.tag == kOutboundTagUrltest) {
          if (ServerManager.getUse().selectDefault !=
              _currentServerForSelector.now) {
            ServerManager.getUse().selectDefault =
                _currentServerForSelector.now;
            ServerManager.saveUse();
          }
        }
      }
      if (_currentServerForSelector.now != now ||
          _currentServerForSelector.history.delay != delay) {
        Future.delayed(const Duration(seconds: 1), () async {
          ServerManager.updateLatencyByHistory();
        });
        setState(() {});
      }
    });
  }

  void _disconnectToCurrent() {
    //Log.w("_disconnectToCurrent");
    if (!_isStarted) {
      _currentServerForSelector.clear();
    }

    _wstimer?.cancel();
    _wstimer = null;
  }

  Future<void> _connectToService() async {
    bool started = await VPNService.started();
    if (!started) {
      return;
    }
    if (_httpClient != null) {
      return;
    }
    if (_wsConnecting) {
      return;
    }
    //Log.w("_connectToService");
    _wsConnecting = true;

    String connectionsUrl = await getConnectionsUrl(true);

    try {
      await _subscriptions?.cancel();
      _httpClient?.close(force: true);
      _httpClient ??= HttpClient();
      _httpClient!.userAgent = await HttpUtils.getUserAgent();
      _httpClient!.connectionTimeout = const Duration(seconds: 3);
      _httpClient!.findProxy = (Uri uri) => "DIRECT";

      {
        WebSocket webSocket =
            await WebSocket.connect(connectionsUrl, customClient: _httpClient);

        _subscriptions = IOWebSocketChannel(webSocket).stream.listen((message) {
          var obj = jsonDecode(message);
          Connection con = Connection();
          con.fromJson(obj, false);
          if (con.startTime != null) {
            _startDurationNotify = DateTime.now()
                .difference(con.startTime!)
                .toString()
                .split(".")[0];
            if (!AppLifecycleStateNofityManager.isPaused()) {
              _startDuration.value = _startDurationNotify;
            }
          }
          _trafficUpTotalNotify =
              ProxyConfUtils.convertTrafficToStringDouble(con.uploadTotal);
          _trafficDownTotalNotify =
              ProxyConfUtils.convertTrafficToStringDouble(con.downloadTotal);
          _trafficUpTotalProxyNotify =
              ProxyConfUtils.convertTrafficToStringDouble(
                  con.uploadTotal - con.uploadTotalDirect);
          _trafficDownTotalProxyNotify =
              ProxyConfUtils.convertTrafficToStringDouble(
                  con.downloadTotal - con.downloadTotalDirect);
          _trafficUpSpeedNotify =
              ProxyConfUtils.convertTrafficToStringDouble(con.uploadSpeed) +
                  "/s";
          _trafficDownSpeedNotify =
              ProxyConfUtils.convertTrafficToStringDouble(con.downloadSpeed) +
                  "/s";

          if (!AppLifecycleStateNofityManager.isPaused()) {
            _trafficUpTotal.value = _trafficUpTotalNotify;
            _trafficDownTotal.value = _trafficDownTotalNotify;

            _trafficUpTotalProxy.value = _trafficUpTotalProxyNotify;
            _trafficDownTotalProxy.value = _trafficDownTotalProxyNotify;

            _trafficUpSpeed.value = _trafficUpSpeedNotify;
            _trafficDownSpeed.value = _trafficDownSpeedNotify;

            _memory.value =
                ProxyConfUtils.convertTrafficToStringDouble(con.memory);

            if (SettingManager.getConfig().dev.devMode) {
              _connInboundCount.value =
                  "${con.connectionsIn}/${con.connectionsOut}/${con.goroutines}/${con.threadCount}";
            } else {
              _connInboundCount.value = con.connectionsIn.toString();
            }
          }

          _updateNetStateLocalNotifications();
        }, onDone: () {
          _disconnectToService();
        }, onError: (error) {});
      }
    } catch (err) {
      Log.w("_connectToService exception ${err.toString()}");
      _disconnectToService();
    }
    _wsConnecting = false;
  }

  Future<void> _disconnectToService() async {
    _removeNetStateLocalNotifications();
    //Log.w("_disconnectToService");

    await _subscriptions?.cancel();
    _subscriptions = null;
    _httpClient?.close();
    _httpClient = null;

    _connInboundCount.value = "";

    _memory.value = "0 B";

    _startDurationNotify = "0:00:00";
    _trafficUpTotalNotify = "0 B";
    _trafficDownTotalNotify = "0 B";
    _trafficUpTotalProxyNotify = "0 B";
    _trafficDownTotalProxyNotify = "0 B";

    _trafficUpSpeedNotify = "0 B/s";
    _trafficDownSpeedNotify = "0 B/s";

    _startDuration.value = _startDurationNotify;
    _trafficUpTotal.value = _trafficUpTotalNotify;
    _trafficDownTotal.value = _trafficDownTotalNotify;
    _trafficUpTotalProxy.value = _trafficUpTotalProxyNotify;
    _trafficDownTotalProxy.value = _trafficDownTotalProxyNotify;
    _trafficUpSpeed.value = _trafficUpSpeedNotify;
    _trafficDownSpeed.value = _trafficDownSpeedNotify;
  }

  void _updateVpnStateLocalNotifications(String state) {
    /*LocalNotifications.notifiy(
        kLocalNotificationsIdVpnStateId,
        kLocalNotificationsIdVpnState,
        AppUtils.getName(),
        state,
        "",
        () => null);*/
  }
  void _updateWanIP() async {
    var setting = SettingManager.getConfig();
    var now = DateTime.now();
    var last = DateTime.tryParse(setting.dns.clientSubnetLatestUpdate);
    if (setting.dns.clientSubnet.isNotEmpty) {
      if (last != null) {
        Duration dur = now.difference(last);
        if (dur < const Duration(hours: 1)) {
          return;
        }
      }
    }
    setting.dns.clientSubnetLatestUpdate = now.toString();
    ReturnResult<String> result = await HttpUtils.httpGetRequest(
        "https://checkip.amazonaws.com/",
        SettingManager.getConfig().proxy.mixedDirectPort,
        null,
        const Duration(seconds: 3),
        null,
        null);

    if (result.error != null) {
      return;
    }

    setting.dns.clientSubnet = result.data!.trim();
    SettingManager.saveConfig();
  }

  void _updateNetStateLocalNotifications() {
    /*final tcontext = Translations.of(context);
    String title =
        "${tcontext.netSpeed} ↑ $_trafficUpSpeedNotify ↓ $_trafficDownSpeedNotify";

    String content =
        "${tcontext.HomeScreen.trafficProxy} ↑ $_trafficUpTotalProxyNotify ↓ $_trafficDownTotalProxyNotify \n";
    content +=
        "${tcontext.HomeScreen.trafficTotal} ↑ $_trafficUpTotalNotify ↓ $_trafficDownTotalNotify\n";
    LocalNotifications.notifiy(kLocalNotificationsIdNetStateId,
        kLocalNotificationsIdNetState, title, content, "", () => null);*/
  }

  void _removeNetStateLocalNotifications() {
    //LocalNotifications.remove(kLocalNotificationsIdNetStateId);
  }

  void _init() async {
    Biz.onInitAllFinish(() async {
      await _onInitAllFinish();
    });
  }

  Future<void> _onInitAllFinish() async {
    NoticeManager.onCheck(() {
      setState(() {});
    });
    AutoUpdateManager.onCheck(() {
      setState(() {});
    });
    DialogUtils.faqCallback = (String text) async {
      AnalyticsUtils.logEvent(
          analyticsEventType: analyticsEventTypeUA,
          name: 'SSS_faq',
          parameters: {"from": "DialogUtils"},
          repeatable: true);
      CommonDialog.loadFAQByError(context, text, true);
    };

    checkError("_onInitAllFinish", showAlert: false);

    if (_currentServer.tag.isEmpty) {
      ProxyConfig? config = ServerManager.getMostRecent();
      if (config != null) {
        _currentServer = config;
        if (_currentServer.groupid != ServerManager.getUrltestGroupId()) {
          ProxyConfig? server =
              ServerManager.getConfig().getByTag(_currentServer.tag);
          if (server != null) {
            _currentServer = server;
          }
        } else {
          _currentServer.latency = "";
        }
        VPNService.setCurrent(_currentServer);
        _currentServerForSelector.clear();
      } else {
        if (ServerManager.getConfig().getServersCount(false) > 0) {
          _currentServer = ServerManager.getUrltest();
          VPNService.setCurrent(_currentServer);
          _currentServerForSelector.clear();
          ServerManager.addRecent(_currentServer);
          ServerManager.saveUse();
        }
      }
    }

    SchemeHandler.vpnConnect = _vpnSchemeConnect;
    SchemeHandler.vpnDisconnect = _vpnSchemeDisconnect;
    SchemeHandler.vpnReconnect = _vpnSchemeReconnect;

    Biz.onRequestStartVPN(_onRequestStartVPN);

    VPNService.onStateChanged(_onStateChanged);
    ServerManager.onAddConfig(_onAddConfig);
    ServerManager.onUpdateConfig(_onUpdateConfig);
    ServerManager.onLatencyUpdateConfig(_onLatencyUpdateConfig);
    //ServerManager.onRemoveConfig(_onRemoveConfig);
    ServerManager.onEnableConfig(_onEnableConfig);
    ServerManager.onRemoteTrafficReload((String groupid) {
      setState(() {});
    }, (String groupid) {
      setState(() {});
    });
    ServerManager.onReloadFromZipConfigs(_onReloadFromZipConfigs);
    ServerManager.onTestLatency(hashCode, _onTestLatency);
    AppLifecycleStateNofityManager.onStateResumed(hashCode, _onStateResumed);
    AppLifecycleStateNofityManager.onStatePaused(hashCode, _onStatePaused);

    if (Platform.isWindows) {
      bool reg =
          SystemSchemeUtils.isRegistered(SystemSchemeUtils.getClashScheme());
      if (!reg) {
        SystemSchemeUtils.register(SystemSchemeUtils.getClashScheme());
      }
    }
    _onInitAllFinished = true;
    _isStarted = await VPNService.started();
    Biz.vpnStateChanged(_isStarted);
    _canConnect = _isStarted;
    if (_canConnect) {
      _connectToCurrent();
      _connectToService();
      _updateWanIP();
    }

    setState(() {});
    if (PlatformUtils.isPC()) {
      if (SettingManager.getConfig().autoConnectAfterLaunch) {
        await start("launch");
      }
    } else if (Platform.isAndroid) {
      String? command = await MainChannel.call("getCommand", {});
      if (command == "connect") {
        ReturnResultError? err = await start("launch");
        if (err == null) {
          moveToBackground();
        }
      }
    }
    if (_initUrl.isNotEmpty) {
      await SchemeHandler.handle(context, _initUrl);
      _initUrl = "";
    }
    _startCheckTimer();
    setState(() {});
  }

  Future<void> _vpnSchemeConnect(bool background) async {
    Future.delayed(const Duration(seconds: 0), () async {
      ReturnResultError? error = await start("scheme");
      if (error == null) {
        if (background) {
          moveToBackground();
        }
      }
    });
  }

  Future<void> _vpnSchemeDisconnect(bool background) async {
    Future.delayed(const Duration(seconds: 0), () async {
      await stop();
      if (background) {
        moveToBackground();
      }
    });
  }

  Future<void> _vpnSchemeReconnect(bool background) async {
    Future.delayed(const Duration(seconds: 0), () async {
      await stop();
      ReturnResultError? error = await start("scheme");
      if (error == null) {
        if (background) {
          moveToBackground();
        }
      }
    });
  }

  Future<ReturnResultError?> _onRequestStartVPN(String from) async {
    return await start(from, disableShowAlertDialog: true);
  }

  Future<void> _onStateChanged(
      FlutterVpnServiceStateChangeReason reason, int code) async {
    if (!_isStarting && !_isStoping) {
      if (reason == FlutterVpnServiceStateChangeReason.start) {
        _updateVpnStateLocalNotifications("start");
        if (_canConnect) {
          _connectToCurrent();
          _connectToService();
          _updateWanIP();
        }
      } else if (reason == FlutterVpnServiceStateChangeReason.restart) {
        _updateVpnStateLocalNotifications("restart");
        _disconnectToCurrent();
        _disconnectToService();

        if (_canConnect) {
          _connectToCurrent();
          _connectToService();
          _updateWanIP();
        }
      } else if (reason == FlutterVpnServiceStateChangeReason.stop ||
          reason == FlutterVpnServiceStateChangeReason.processexit) {
        _updateVpnStateLocalNotifications("stop");
        _disconnectToCurrent();
        _disconnectToService();

        checkError("onStateChanged");
      } else if (reason == FlutterVpnServiceStateChangeReason.syncstate) {
        return;
      }
      updateTile();
    }

    if (reason == FlutterVpnServiceStateChangeReason.processexit && code != 0) {
      AnalyticsUtils.logEvent(
          analyticsEventType: analyticsEventTypeApp,
          name: 'HSS_serviceQuit',
          parameters: {
            "code": code,
          });
    }
  }

  Future<void> _onAddConfig(ServerConfigGroupItem item) async {
    if (_currentServer.groupid.isEmpty) {
      _currentServer = ServerManager.getUrltest();
      VPNService.setCurrent(_currentServer);

      ServerManager.addRecent(_currentServer);
      ServerManager.saveUse();
    }
    await setServerAndReload("onAddConfig");
  }

  Future<void> _onUpdateConfig(List<ServerConfigGroupItem> groups) async {
    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    if (noConfig) {
      setState(() {});
      return;
    }
    bool reload = false;
    for (var group in groups) {
      if (group.enable && group.reloadAfterProfileUpdate) {
        reload = true;
        break;
      }
    }
    if (!reload) {
      setState(() {});
      return;
    }

    await setServerAndReload("onUpdateConfig");
  }

  Future<void> _onLatencyUpdateConfig(Set<ServerConfigGroupItem> groups) async {
    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    if (noConfig) {
      setState(() {});
      return;
    }
    bool reload = false;
    for (var group in groups) {
      if (group.enable && group.testLatencyAutoRemove) {
        reload = true;
        break;
      }
    }
    if (!reload) {
      setState(() {});
      return;
    }

    await setServerAndReload("onLatencyUpdateConfig");
  }

  Future<void> _onRemoveConfig(
      String groupid, bool enable, bool hasDeviersionGroup) async {
    if (!enable) {
      return;
    }
    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    if (noConfig) {
      _currentServer = ProxyConfig();
      VPNService.setCurrent(_currentServer);

      await stop();

      return;
    }
    if (groupid == _currentServer.groupid) {
      _currentServer = ServerManager.getUrltest();
      VPNService.setCurrent(_currentServer);

      ServerManager.addRecent(_currentServer);
      ServerManager.saveUse();
    }
    await setServerAndReload("onRemoveConfig");
  }

  Future<void> _onEnableConfig(String groupid, bool enable) async {
    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    if (noConfig) {
      _currentServer = ProxyConfig();
      VPNService.setCurrent(_currentServer);

      await stop();

      return;
    }
    if (!enable) {
      return;
    }
    if (groupid == _currentServer.groupid) {
      _currentServer = ServerManager.getUrltest();
      VPNService.setCurrent(_currentServer);

      ServerManager.addRecent(_currentServer);
      ServerManager.saveUse();
    }
    await setServerAndReload("onEnableConfig");
  }

  Future<void> _onReloadFromZipConfigs() async {
    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    if (noConfig) {
      _currentServer = ProxyConfig();
      VPNService.setCurrent(_currentServer);

      await stop();
      return;
    }
    ProxyConfig? config = ServerManager.getMostRecent();
    if (config != null) {
      _currentServer = config;
      if (_currentServer.groupid != ServerManager.getUrltestGroupId()) {
        ProxyConfig? server =
            ServerManager.getConfig().getByTag(_currentServer.tag);
        if (server != null) {
          _currentServer = server;
        }
      }

      VPNService.setCurrent(_currentServer);
    } else {
      _currentServer = ServerManager.getUrltest();
      VPNService.setCurrent(_currentServer);

      ServerManager.addRecent(_currentServer);
      ServerManager.saveUse();
    }

    setState(() {});
  }

  Future<void> _onTestLatency(
      String groupid, String tag, bool start, bool finish) async {
    if (!mounted) {
      return;
    }

    if ((groupid == _currentServer.groupid && tag == _currentServer.tag) ||
        (tag == _currentServerForSelector.now)) {
      ServerConfigGroupItem? item = ServerManager.getByGroupId(groupid);
      if (item != null) {
        ProxyConfig? ppc = item.getByTag(tag);
        if (ppc != null) {
          _currentServer.latency = ppc.latency;
          setState(() {});
        }
      }
    }
    if (finish) {
      if (ServerManager.getUrltestGroupId() == _currentServer.groupid) {
        if (SettingManager.getConfig()
            .autoSelect
            .updateCurrentServerAfterManualUrltest) {
          await ClashApi.updateUrltestCheck(
              SettingManager.getConfig().proxy.controlPort);
          ReturnResult<CurrentServerForSelector> result =
              await ClashApi.getCurrentServerForUrltest(
                  ServerManager.getUrltestTagForCustom(_currentServer.tag),
                  SettingManager.getConfig().proxy.controlPort);

          if (result.error != null) {
            _currentServerForSelector.clear();
          } else {
            _currentServerForSelector = result.data!;
            _currentServer.latency = _currentServerForSelector.history.delay > 0
                ? _currentServerForSelector.history.delay.toString()
                : _currentServerForSelector.history.error;

            ProxyConfig? proxy = ServerManager.getConfig()
                .getByTag(_currentServerForSelector.now);
            if (proxy != null) {
              proxy.latency = _currentServer.latency;
            }
            if (_currentServer.groupid == ServerManager.getUrltestGroupId() &&
                _currentServer.tag == kOutboundTagUrltest) {
              if (ServerManager.getUse().selectDefault !=
                  _currentServerForSelector.now) {
                ServerManager.getUse().selectDefault =
                    _currentServerForSelector.now;
                ServerManager.saveUse();
              }
            }
          }
        }
      }
    }
  }

  Future<void> _onStateResumed() async {
    if (!_isStarting && !_isStoping) {
      bool started = await VPNService.started();
      if (started != _isStarted) {
        _isStarted = started;
        Biz.vpnStateChanged(_isStarted);
        setState(() {});
      }
      _canConnect = _isStarted;
    }
    _startCheckTimer();
    _showNotify();

    if (PlatformUtils.maybeTV()) {
      _focusNodeSettings.requestFocus();
    }
  }

  Future<void> _onStatePaused() async {
    if (!_isStarting) {
      _canConnect = false;
    }
    _stopCheckTimer();
    _disconnectToCurrent();
    _disconnectToService();
  }

  Future<Tuple2<ReturnResultError?, int?>> setServer() async {
    final tcontext = Translations.of(context);
    String savePath = await PathUtils.serviceCoreConfigFilePath();
    VPNServiceSetServerOptions options = VPNServiceSetServerOptions();
    options.disabledServerError = tcontext.HomeScreen.disabledServer;
    options.invalidServerError = tcontext.HomeScreen.invalidServer;
    options.expiredServerError = tcontext.HomeScreen.expiredServer;
    ReturnResultError? err = await VPNService.setServer(
        _currentServer, options, SingboxExportType.karing, null, "", savePath);
    if (err != null) {
      return Tuple2(err, options.allOutboundsTags.length);
    }
    if (Platform.isIOS) {
      const int maxCount = 1500;
      if (options.allOutboundsTags.length > maxCount) {
        InAppNotifications.show(
            title: tcontext.tips,
            duration: const Duration(seconds: 3),
            leading: const Icon(
              Icons.warning,
              color: Colors.yellow,
              size: 50,
            ),
            description: tcontext.HomeScreen.tooMuchServers(
                p: options.allOutboundsTags.length, p1: maxCount),
            onTap: () {
              InAppNotifications.dismiss();
            });
      }
    }

    return Tuple2(null, options.allOutboundsTags.length);
  }

  Future<void> setServerAndReload(String from) async {
    bool run = await VPNService.running();
    if (!run) {
      return;
    }
    await ProxyCluster.stop();
    _disconnectToCurrent();
    _disconnectToService();
    _currentServerForSelector.clear();
    _isStarting = true;
    _isStarted = false;
    _canConnect = _isStarted;
    setState(() {});
    var result = await setServer();
    bool tunMode = await VPNService.getTunMode();
    if (result.item1 == null) {
      var err = await VPNService.reload(
          VPNService.getTimeoutByOutboundCount(result.item2!, tunMode));
      _isStarting = false;
      _isStarted = err == null;
      _canConnect = _isStarted;
      setState(() {});
      if (err != null) {
        AnalyticsUtils.logEvent(
            analyticsEventType: analyticsEventTypeApp,
            name: 'HSS_reload',
            parameters: {
              "err": err.message,
              "from": from,
              "tunMode": tunMode,
              "count": result.item2,
            });
        CommonDialog.handleStartError(context, err.message);
      } else {
        if (PlatformUtils.isPC()) {
          var settingConfig = SettingManager.getConfig();
          if (settingConfig.proxy.enableCluster) {
            String? error = await ProxyCluster.start();
            if (error != null) {
              DialogUtils.showAlertDialog(context, error,
                  showCopy: true, showFAQ: true, withVersion: true);
            }
          }
        }
      }
    } else {
      _isStarting = false;
      _isStarted = false;
      _canConnect = _isStarted;
      _isStoping = true;
      setState(() {});
      await VPNService.stop();
      _isStoping = false;
      setState(() {});
      await Yacd.stop();
    }
  }

  Future<bool> getSystemProxy() async {
    if (PlatformUtils.isPC()) {
      _isSystemProxySet = await VPNService.getSystemProxy();
      return _isSystemProxySet;
    }
    return false;
  }

  Material createServerSelect(BuildContext context) {
    final tcontext = Translations.of(context);
    var setting = SettingManager.getConfig();
    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    String text = "";
    String delay = _currentServer.latency;
    String groupid = "";
    String tag = "";
    if (noConfig) {
      text = tcontext.addProfile;
    } else {
      if (_currentServer.groupid == ServerManager.getUrltestGroupId()) {
        text = tcontext.outboundActionUrltest;
        if (_currentServer.tag != kOutboundTagUrltest) {
          text += "[${_currentServer.tag}]";
        }

        if (_currentServerForSelector.now.isNotEmpty) {
          text += "[${_currentServerForSelector.now}]";
          ProxyConfig? proxy =
              ServerManager.getConfig().getByTag(_currentServerForSelector.now);
          if (proxy != null) {
            tag = _currentServerForSelector.now;
            groupid = proxy.groupid;
          }
        }
      } else if (_currentServer.groupid == ServerManager.getDirectGroupId()) {
        text = tcontext.outboundActionDirect;
        tag = _currentServer.tag;
        groupid = _currentServer.groupid;
      } else if (_currentServer.groupid == ServerManager.getBlockGroupId()) {
        text = tcontext.outboundActionBlock;
        tag = _currentServer.tag;
        groupid = _currentServer.groupid;
      } else {
        text = _currentServer.tag;
        tag = _currentServer.tag;
        groupid = _currentServer.groupid;
      }
    }
    if (setting.originSBProfile.isNotEmpty) {
      text = path.basename(setting.originSBProfile);
      delay = "";
      tag = "";
      groupid = "";
    }

    Size windowSize = MediaQuery.of(context).size;
    return Material(
      color: Colors.grey.withOpacity(0.5),
      child: InkWell(
        focusNode: _focusNodeSelect,
        onTap: setting.originSBProfile.isNotEmpty
            ? null
            : () async {
                if (noConfig) {
                  onTapAddProfileByStart();
                } else {
                  await onTapServerSelect();
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          width: double.infinity,
          height: 60,
          child: Row(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 10,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            alignment: Alignment.center,
                            width: windowSize.width -
                                10 * 2 -
                                10 -
                                CommonWidget.kLatencyWidget -
                                25 -
                                5,
                            height: 60,
                            child: Text(
                              text,
                              style: TextStyle(
                                fontWeight: ThemeConfig.kFontWeightListSubItem,
                                fontSize: ThemeConfig.kFontSizeListSubItem,
                                fontFamily: Platform.isWindows ? 'Emoji' : null,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          CommonWidget.createLatencyWidget(
                            context,
                            null,
                            false,
                            false,
                            delay,
                            onTapLatencyReload: tag.isEmpty || groupid.isEmpty
                                ? null
                                : () async {
                                    bool started = await VPNService.started();
                                    if (!started) {
                                      var err = await start("latencyWidget",
                                          disableShowAlertDialog: false);
                                      if (err != null) {
                                        return;
                                      }
                                    }

                                    ServerManager.testOutboundLatencyForServer(
                                            tag, groupid)
                                        .then((err) {
                                      if (!mounted) {
                                        return;
                                      }
                                      setState(() {});
                                      if (err != null) {
                                        DialogUtils.showAlertDialog(
                                            context, err.message,
                                            showCopy: true,
                                            showFAQ: true,
                                            withVersion: true);
                                      }
                                    });
                                  },
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 25,
                child: setting.originSBProfile.isNotEmpty
                    ? null
                    : const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void changeTheme(String theme) {
    if (SettingManager.getConfig().ui.theme == theme) {
      return;
    }

    SettingManager.getConfig().ui.theme = theme;
    SettingManager.saveConfig();
    Provider.of<Themes>(context, listen: false).setTheme(theme, true);

    setState(() {});
  }

  void onTapSetting() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: SettingsScreen.routSettings(),
            builder: (context) => const SettingsScreen()));
    await checkAndReload("onTapSetting");
    setState(() {});
  }

  void onTapToggleStart() async {
    await GroupHelper.showAddProfile(context, false);
    await checkAndReload("onTapToggleStart");
    setState(() {});
  }

  void onTapSpeedTest() async {
    final tcontext = Translations.of(context);
    var setting = SettingManager.getConfig();
    await WebviewHelper.loadUrl(context,
        !setting.novice ? setting.speedTest : SettingConfig.kSpeedTestList[0],
        title: tcontext.SettingsScreen.speedTest);
  }

  void onTapLink() async {
    final tcontext = Translations.of(context);
    if (SettingManager.getConfig().uiScreen.myLink.isEmpty) {
      await DialogUtils.showAlertDialog(
          context, tcontext.HomeScreen.myLinkEmpty);
    } else {
      await WebviewHelper.loadUrl(
          context, SettingManager.getConfig().uiScreen.myLink,
          title: SettingManager.getConfig().uiScreen.myLink);
    }
  }

  void onTapAppleTV() async {
    GroupHelper.showAppleTVByScanQRCode(context);
  }

  void onTapMyProfiles() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: MyProfilesScreen.routSettings(),
            builder: (context) => const MyProfilesScreen()));
    await checkAndReload("onTapMyProfiles");
    setState(() {});
  }

  void onTapAddProfile() async {
    await GroupHelper.showAddProfile(context, false);
    await checkAndReload("onTapAddProfile");
    setState(() {});
  }

  void onTapAddProfileByAgreement() async {
    await GroupHelper.showAddProfile(context, true);
    await checkAndReload("onTapAddProfileByAgreement");
    setState(() {});
  }

  void onTapAddProfileByStart() async {
    await GroupHelper.showAddProfile(context, false);
    await checkAndReload("onTapAddProfileByStart");
    setState(() {});
  }

  void onTapDNS() async {
    await GroupHelper.showDns(context);
    await checkAndReload("onTapDNS");
    setState(() {});
  }

  void onTapDiversion() async {
    await GroupHelper.showDeversion(context);
    await checkAndReload("onTapDiversion");
    setState(() {});
  }

  void onTapNetCheck() async {
    Navigator.push(
        context,
        MaterialPageRoute(
            settings: NetCheckScreen.routSettings(),
            builder: (context) => const NetCheckScreen()));
  }

  void onTapSetTheme() async {
    String theme = SettingManager.getConfig().ui.theme;
    showMenu(
        context: context,
        position: const RelativeRect.fromLTRB(0.1, 0, 0, 0),
        items: [
          PopupMenuItem(
              value: 0,
              child: Container(
                  alignment: Alignment.center,
                  width: 86,
                  height: 26,
                  color: theme == ThemeDefine.kThemeSystem
                      ? ThemeDefine.kColorGreenBright
                      : null,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: ThemeDataLight.homeColor,
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: ThemeDataDark.homeColor,
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: ThemeDataLight.homeColor,
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: ThemeDataDark.homeColor,
                            ),
                          )
                        ],
                      ))),
              onTap: () {
                changeTheme(ThemeDefine.kThemeSystem);
              }),
          PopupMenuItem(
              value: 1,
              child: Container(
                  alignment: Alignment.center,
                  width: 86,
                  height: 26,
                  color: theme == ThemeDefine.kThemeLight
                      ? ThemeDefine.kColorGreenBright
                      : null,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: ThemeDataLight.homeColor,
                            ),
                          ),
                        ],
                      ))),
              onTap: () {
                changeTheme(ThemeDefine.kThemeLight);
              }),
          PopupMenuItem(
            value: 1,
            child: Container(
                alignment: Alignment.center,
                width: 86,
                height: 26,
                color: theme == ThemeDefine.kThemeDark
                    ? ThemeDefine.kColorGreenBright
                    : null,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: ThemeDataDark.homeColor,
                          ),
                        ),
                      ],
                    ))),
            onTap: () {
              changeTheme(ThemeDefine.kThemeDark);
            },
          ),
          PopupMenuItem(
              value: 0,
              child: Container(
                  alignment: Alignment.center,
                  width: 86,
                  height: 26,
                  color: theme == ThemeDefine.kThemeBlue
                      ? ThemeDefine.kColorGreenBright
                      : null,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: ThemeDataBlue.homeColor,
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: ThemeDataLight.homeColor,
                            ),
                          )
                        ],
                      ))),
              onTap: () {
                changeTheme(ThemeDefine.kThemeBlue);
              }),
        ]);
  }

  void onTapNotice(NoticeItem noticeItem) async {
    AnalyticsUtils.logEvent(
        analyticsEventType: analyticsEventTypeUA,
        name: 'HSS_notice',
        parameters: {"title": noticeItem.title, "isp_id": noticeItem.ispId},
        repeatable: true);

    InAppNotifications.dismiss();
    _inAppNotificationsShowing = false;
    if (noticeItem.url.isNotEmpty) {
      String url = noticeItem.ispId.isNotEmpty
          ? noticeItem.url
          : await UrlLauncherUtils.reorganizationUrlWithAnchor(noticeItem.url);
      if (!context.mounted) {
        return;
      }
      await WebviewHelper.loadUrl(context, url, title: noticeItem.title);
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: RichtextViewScreen.routSettings(),
              builder: (context) => RichtextViewScreen(
                  title: t.notice, file: "", content: noticeItem.content)));
    }
    noticeItem.readed = true;
    NoticeManager.saveConfig();

    setState(() {});
    Future.delayed(const Duration(seconds: 0), () async {
      if (!mounted) {
        return;
      }
      _showNotify();
    });
  }

  Future<String> getConnectionsUrl(bool noConnections) async {
    return await ClashApi.getConnectionsUrl(
        SettingManager.getConfig().proxy.controlPort,
        noConnections: noConnections);
  }

  Future<void> onTapNetConnections() async {
    String connectionsUrl = await getConnectionsUrl(false);
    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: NetConnectionsScreen.routSettings(),
            builder: (context) => NetConnectionsScreen(
                  connectionsUrl: connectionsUrl,
                )));
    await checkAndReload("onTapNetConnections");
  }

  Future<void> onLongPressNetConnections() async {
    await ClashApi.resetOutboundConnections(
      SettingManager.getConfig().proxy.controlPort,
    );
  }

  Future<void> onTapServerSelect() async {
    ProxyConfig? result = await Navigator.push(
        context,
        MaterialPageRoute(
            settings: ServerSelectScreen.routSettings(),
            builder: (context) => ServerSelectScreen(
                  singleSelect: ServerSelectScreenSingleSelectedOption(
                    selectedServer: _currentServer,
                    showAutoSelect: true,
                    showDirect: true,
                    showUrltestGroup: true,
                  ),
                  multiSelect: null,
                )));
    if (result != null) {
      if (!_currentServer.isSame(result) || ServerManager.getDirty()) {
        _currentServer = result;
        _currentServerForSelector.clear();
        ServerManager.addRecent(result);
        var use = ServerManager.getUse();
        if (use.selectDefault != result.tag &&
            result.latency.isNotEmpty &&
            int.tryParse(result.latency) != null &&
            result.type != kOutboundTypeUrltest) {
          use.selectDefault = result.tag;
        }
        await setServerAndReload("ServerSelectScreen");
      } else {
        _currentServer = result;
      }
      VPNService.setCurrent(_currentServer);
    }
    ServerManager.setDirty(false);
    setState(() {});
  }

  Future<void> checkAndReload(String from) async {
    if (!_isStarted && !_isStarting) {
      return;
    }
    if (SettingManager.getDirty() || ServerManager.getDirty()) {
      if (_currentServer.groupid.isEmpty) {
        _currentServer = ServerManager.getUrltest();
        VPNService.setCurrent(_currentServer);

        ServerManager.addRecent(_currentServer);
        ServerManager.saveUse();
      }
      if (SettingManager.getDirty()) {
        SettingManager.setDirty(false);
        SettingManager.saveConfig();
      }

      ServerManager.setDirty(false);
      bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
      if (noConfig) {
        await stop();
        return;
      }
      await setServerAndReload(from);
    }
  }

  Future<void> onTapToggle() async {
    bool run = await VPNService.running();
    if (run) {
      await stop();
    } else {
      await start("switch");
    }
  }

  Future<void> stop() async {
    _currentServerForSelector.clear();
    await ProxyCluster.stop();
    await Yacd.stop();
    if (_currentServer.groupid == ServerManager.getUrltestGroupId()) {
      _currentServer.latency = "";
      _currentServerForSelector.history.clear();
    }

    _isStarting = false;
    _isStarted = false;
    setState(() {});
    Biz.vpnStateChanged(_isStarted);
    bool run = await VPNService.running();
    if (run) {
      AnalyticsUtils.logEvent(
          analyticsEventType: analyticsEventTypeApp,
          name: 'HSS_stop',
          parameters: {
            "server": _currentServer.server,
            "type": _currentServer.type,
          });
      _isStoping = true;
      setState(() {});
      await VPNService.stop();
      _isStoping = false;
      setState(() {});
    }
  }

  Future<ReturnResultError?> start(String from,
      {bool disableShowAlertDialog = false}) async {
    _currentServerForSelector.clear();
    await ProxyCluster.stop();

    if (Platform.isWindows) {
      List<String> filePaths = [
        PathUtils.serviceExePath(),
      ];
      List<String> dirPaths = [PathUtils.flutterAssetsDir()];
      for (var filePath in filePaths) {
        var file = File(filePath);
        bool exist = await file.exists();
        if (!exist) {
          final tcontext = Translations.of(context);
          if (!disableShowAlertDialog) {
            DialogUtils.showAlertDialog(
                context, tcontext.fileNotExistReinstall(p: filePath),
                showCopy: true, showFAQ: true, withVersion: true);
          }
          return ReturnResultError(tcontext.fileNotExistReinstall(p: filePath));
        }
      }
      for (var filePath in dirPaths) {
        var file = Directory(filePath);
        bool exist = await file.exists();
        if (!exist) {
          final tcontext = Translations.of(context);
          if (!disableShowAlertDialog) {
            DialogUtils.showAlertDialog(
                context, tcontext.fileNotExistReinstall(p: filePath),
                showCopy: true, showFAQ: true, withVersion: true);
          }
          return ReturnResultError(tcontext.fileNotExistReinstall(p: filePath));
        }
      }
    }
    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    if (noConfig) {
      Log.w("start failed: no server avaliable, from $from");
      return ReturnResultError("start failed: no server avaliable");
    }
    if (_currentServer.groupid.isEmpty) {
      Log.w("start failed: groupid is empty, from $from");
      return ReturnResultError("start failed: groupid is empty");
    }
    if (_isStarting) {
      Log.w("start failed: starting, from $from");
      return ReturnResultError("start failed: starting");
    }
    bool run = await VPNService.running();
    if (run) {
      return null;
    }
    _isStarting = true;
    _isStarted = false;
    _canConnect = _isStarted;
    setState(() {});
    var result = await setServer();
    bool tunMode = await VPNService.getTunMode();
    if (result.item1 != null) {
      _isStarting = false;
      _isStarted = false;
      Biz.vpnStateChanged(_isStarted);
      _canConnect = _isStarted;
      setState(() {});
      if (result.item1!.report) {
        AnalyticsUtils.logEvent(
            analyticsEventType: analyticsEventTypeApp,
            name: 'HSS_start',
            parameters: {
              "err": result.item1!.message,
              "from": from,
              "tunMode": tunMode,
              "count": result.item2,
            });
      }

      if (!disableShowAlertDialog) {
        CommonDialog.handleStartError(context, result.item1!.message);
      }
      return result.item1;
    }
    ServerManager.setDirty(false);
    SettingManager.setDirty(false);
    var err = await VPNService.start(
        VPNService.getTimeoutByOutboundCount(result.item2!, tunMode));
    _isStarting = false;
    _isStarted = err == null;
    Biz.vpnStateChanged(_isStarted);
    _canConnect = _isStarted;

    setState(() {});

    AnalyticsUtils.logEvent(
        analyticsEventType: analyticsEventTypeApp,
        name: 'HSS_start',
        parameters: {
          "err": (err != null) ? err.message : null,
          "from": from,
          "tunMode": tunMode,
          "count": result.item2,
        });
    if (err != null) {
      if (!disableShowAlertDialog) {
        CommonDialog.handleStartError(context, err.message);
      }
    } else {
      if (PlatformUtils.isPC()) {
        var settingConfig = SettingManager.getConfig();
        if (settingConfig.proxy.enableCluster) {
          String? error = await ProxyCluster.start();
          if (error != null) {
            if (!disableShowAlertDialog) {
              DialogUtils.showAlertDialog(context, error,
                  showCopy: true, showFAQ: true, withVersion: true);
            }
          }
        }
      }
    }
    return err;
  }

  @override
  void onProtocolUrlReceived(String url) {
    Log.i("onProtocolUrlReceived: $url");
    if (!mounted) {
      return;
    }
    if (!_onInitAllFinished) {
      _initUrl = url;
      return;
    }
    SchemeHandler.handle(context, url);
  }

  @override
  void dispose() {
    _focusNodeSettings.dispose();
    _focusNodeTheme.dispose();
    _focusNodeSwitch.dispose();
    _focusNodeSelect.dispose();

    _focusNodeSystemProxyTips.dispose();
    _focusNodeSystemProxy.dispose();
    _focusNodeRule.dispose();
    _focusNodeGlobal.dispose();
    _focusNodeConnections.dispose();

    _focusNodeToolbar.clear();
    _focusNodeMyProfiles.dispose();
    _focusNodeAddProfile.dispose();
    _focusNodeDNS.dispose();
    _focusNodeDeversion.dispose();
    _focusNodeNetcheck.dispose();
    _focusNodeSpeedtest.dispose();
    _focusNodeMyLink.dispose();
    _focusNodeAppleTV.dispose();
    _focusNodeMore.dispose();

    ErrorReporterUtils.register(null);
    _stopCheckTimer();

    _disconnectToService();
    _disconnectToCurrent();

    protocolHandler.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tcontext = Translations.of(context);
    Size windowSize = MediaQuery.of(context).size;
    var settingConfig = SettingManager.getConfig();
    AutoUpdateCheckVersion checkVersion = AutoUpdateManager.getVersionCheck();
    List<Notice> notices = NoticeManager.getNotices();
    NoticeItem? noticeItem;
    for (var notice in notices) {
      noticeItem = notice.getFirstUnread();
      if (noticeItem != null) {
        break;
      }
    }

    bool noConfig = ServerManager.getConfig().getServersCount(false) == 0;
    bool showAds = AdsBannerWidget.getEnable();

    double height =
        AdsBannerWidget.getRealHeight(true, showAds, AdsBannerWidget.adHeight);
    var themes = Provider.of<Themes>(context, listen: false);
    Color? color = themes.getThemeHomeColor(context);

    return Focus(
        includeSemantics: true,
        onKeyEvent: onKeyEvent,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.zero,
            child: AppBar(
              backgroundColor: color,
              systemOverlayStyle: SystemUiOverlayStyle(
                systemNavigationBarIconBrightness:
                    themes.getStatusBarIconBrightness(context),
                systemNavigationBarColor: color,
                systemNavigationBarDividerColor: Colors.transparent,
                statusBarColor: color,
                statusBarBrightness: themes.getStatusBarBrightness(context),
                statusBarIconBrightness:
                    themes.getStatusBarIconBrightness(context),
              ),
            ),
          ),
          backgroundColor: color,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Tooltip(
                                message: tcontext.setting,
                                child: InkWell(
                                    autofocus: PlatformUtils.maybeTV(),
                                    focusNode: _focusNodeSettings,
                                    onTap: () async {
                                      onTapSetting();
                                    },
                                    child: Stack(
                                      children: [
                                        const SizedBox(
                                          width: 50,
                                          height: 30,
                                          child: Icon(
                                            Icons.settings_outlined,
                                            size: 26,
                                          ),
                                        ),
                                        checkVersion.newVersion ||
                                                noticeItem != null
                                            ? Positioned(
                                                left: 10,
                                                top: 0,
                                                child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                    )),
                                              )
                                            : const SizedBox(
                                                width: 0,
                                              ),
                                      ],
                                    ))),
                            Row(children: createToolbar()),
                          ]),
                      Tooltip(
                        message: tcontext.SettingsScreen.theme,
                        child: InkWell(
                          focusNode: _focusNodeTheme,
                          onTap: () async {
                            onTapSetTheme();
                          },
                          child: const SizedBox(
                            width: 50,
                            height: 30,
                            child: Icon(
                              Icons.color_lens_outlined,
                              size: 26,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 20,
                        ),
                        showAds
                            ? AdsBannerWidget(
                                fixedHeight: true,
                                adWidth: windowSize.width,
                              )
                            : SizedBox(
                                height: height,
                              ),
                        Container(
                          alignment: Alignment.center,
                          child: Stack(children: [
                            SizedBox(
                              width: 180,
                              child: FittedBox(
                                fit: BoxFit.fill,
                                child: Switch.adaptive(
                                  value: _isStarted,
                                  focusNode: _focusNodeSwitch,
                                  activeColor: ThemeDefine.kColorGreenBright,
                                  thumbColor:
                                      WidgetStateProperty.resolveWith<Color>(
                                          (Set<WidgetState> states) {
                                    return Colors.orange;
                                  }),
                                  inactiveTrackColor: noConfig
                                      ? Colors.grey
                                      : Colors.grey.withOpacity(0.5),
                                  onChanged: (bool newValue) async {
                                    if (noConfig) {
                                      onTapToggleStart();
                                    } else {
                                      if (!_isStarting && !_isStoping) {
                                        onTapToggle();
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                            SizedBox(
                                width: 150,
                                height: 150,
                                child: _isStarting || _isStoping
                                    ? Container(
                                        alignment: const Alignment(-0.25, 0),
                                        child: const RepaintBoundary(
                                            child: CircularProgressIndicator(
                                                color: ThemeDefine
                                                    .kColorGreenBright)),
                                      )
                                    : null),
                          ]),
                        ),
                        /*AnimatedToggleSwitch<bool>.dual(
                            current: _isStarted,
                            first: false,
                            second: true,
                            spacing: 65.0,
                            animationDuration:
                                const Duration(milliseconds: 600),
                            style: const ToggleStyle(
                              borderColor: Colors.transparent,
                              indicatorColor: Colors.white,
                              backgroundColor: Colors.amber,
                            ),
                            customStyleBuilder: (context, local, global) =>
                                ToggleStyle(
                                    backgroundGradient: LinearGradient(
                              colors: const [
                              
                                Colors.red
                              ],
                              stops: [
                                global.position -
                                    (1 - 2 * max(0, global.position - 0.5)) *
                                        0.5,
                                global.position +
                                    max(0, 2 * (global.position - 0.5)) * 0.5,
                              ],
                            )),
                            borderWidth: 6.0,
                            height: 60.0,
                            loadingIconBuilder: (context, global) =>
                                CupertinoActivityIndicator(
                                    color: Color.lerp(
                                        Colors.red,
                                     
                                        global.position)),
                            onChanged: (b) async {
                              if (noConfig) {
                                 onTapToggleStart();
                              } else {
                                if (!_isStarting) {
                                  setState(() {});
                                  await onTapToggle();
                                }
                              }
                            },
                            iconBuilder: (value) => value
                                ? const Icon(Icons.power_outlined,
                                 
                                    size: 32.0)
                                : const Icon(Icons.power_settings_new_rounded,
                                    color: Colors.red, size: 32.0),
                            textBuilder: (value) => Center(
                                child: Text(
                              value ? 'ON' : 'OFF',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30.0,
                                  fontWeight: FontWeight.w600),
                            )),
                          ),
                          const SizedBox(
                            height: 35,
                          ),*/
                        Column(
                          children: [
                            Platform.isWindows ||
                                    Platform.isMacOS ||
                                    Platform.isLinux
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Tooltip(
                                              message: tcontext.HomeScreen
                                                  .systemProxyTips(
                                                      hp: settingConfig
                                                          .proxy.mixedRulePort,
                                                      sp: settingConfig
                                                          .proxy.mixedRulePort),
                                              child: InkWell(
                                                focusNode:
                                                    _focusNodeSystemProxyTips,
                                                onTap: () {
                                                  DialogUtils.showAlertDialog(
                                                      context,
                                                      tcontext.HomeScreen
                                                          .systemProxyTips(
                                                              hp: settingConfig
                                                                  .proxy
                                                                  .mixedRulePort,
                                                              sp: settingConfig
                                                                  .proxy
                                                                  .mixedRulePort));
                                                },
                                                child: const Icon(
                                                  Icons.info_outlined,
                                                  size: 20,
                                                ),
                                              )),
                                          const SizedBox(
                                            width: 15,
                                          ),
                                          Text(
                                            tcontext.systemProxy,
                                            style: const TextStyle(
                                              fontSize:
                                                  ThemeConfig.kFontSizeListItem,
                                            ),
                                          ),
                                          FutureBuilder(
                                            future: getSystemProxy(),
                                            builder: (BuildContext context,
                                                AsyncSnapshot<bool> snapshot) {
                                              return Switch.adaptive(
                                                focusNode:
                                                    _focusNodeSystemProxy,
                                                value: snapshot.hasData &&
                                                    snapshot.data!,
                                                activeColor: ThemeDefine
                                                    .kColorGreenBright,
                                                onChanged: noConfig
                                                    ? null
                                                    : (bool newValue) {
                                                        if (!_isStarting &&
                                                            !_isStoping) {
                                                          VPNService
                                                              .setSystemProxy(
                                                                  newValue);
                                                          setState(() {});
                                                        }
                                                      },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                            const SizedBox(
                              height: 10,
                            ),
                            SizedBox(
                              child: SegmentedButtonEx<bool>(
                                segments: <ButtonSegmentEx<bool>>[
                                  ButtonSegmentEx<bool>(
                                      value: false,
                                      focusNode: _focusNodeRule,
                                      label: Text(
                                        tcontext.rule,
                                        style: const TextStyle(
                                          fontSize:
                                              ThemeConfig.kFontSizeListSubItem,
                                        ),
                                      )),
                                  ButtonSegmentEx<bool>(
                                      value: true,
                                      focusNode: _focusNodeGlobal,
                                      label: Text(
                                        tcontext.global,
                                        style: const TextStyle(
                                          fontSize:
                                              ThemeConfig.kFontSizeListSubItem,
                                        ),
                                      )),
                                ],
                                selected: {SettingManager.getConfig().proxyAll},
                                onSelectionChanged:
                                    (Set<bool> newSelection) async {
                                  SettingManager.getConfig().proxyAll =
                                      newSelection.first;
                                  SettingManager.saveConfig();
                                  setState(() {});
                                  await setServerAndReload("proxyAll");
                                },
                                multiSelectionEnabled: false,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  createGroupTraffic(context),
                                ]),
                            const SizedBox(
                              height: 10,
                            ),
                            createNetStatusChart(context),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [createServerSelect(context)],
                ),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ));
  }

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      List<List<FocusNode>> nodes = [];
      List<FocusNode> node1 = [_focusNodeSettings];
      node1.addAll(_focusNodeToolbar);
      node1.add(_focusNodeTheme);
      nodes.add(node1);
      nodes.add([_focusNodeSwitch]);
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        nodes.add([_focusNodeSystemProxyTips, _focusNodeSystemProxy]);
      }
      nodes.add([_focusNodeRule, _focusNodeGlobal]);
      nodes.add([_focusNodeConnections]);
      nodes.add([_focusNodeSelect]);

      switch (event.logicalKey) {
        case LogicalKeyboardKey.contextMenu:
          var focus = [_focusNodeSettings, _focusNodeSwitch, _focusNodeSelect];
          int? focusIndex;
          for (int i = 0; i < focus.length; ++i) {
            if (focus[i].hasFocus) {
              focusIndex = i;
              break;
            }
          }
          if (focusIndex == null) {
            _focusNodeSwitch.requestFocus();
          } else {
            focus[(focusIndex + 1) % focus.length].requestFocus();
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          for (int i = 1; i < nodes.length; ++i) {
            List<FocusNode> node = nodes[i];
            for (int j = 0; j < node.length; ++j) {
              if (node[j].hasFocus) {
                nodes[i - 1][0].requestFocus();
                return KeyEventResult.handled;
              }
            }
          }

        case LogicalKeyboardKey.arrowDown:
          for (int i = 0; i < nodes.length - 1; ++i) {
            List<FocusNode> node = nodes[i];
            for (int j = 0; j < node.length; ++j) {
              if (node[j].hasFocus) {
                nodes[i + 1][0].requestFocus();
                return KeyEventResult.handled;
              }
            }
          }

        case LogicalKeyboardKey.arrowLeft:
          for (int i = 0; i < nodes.length; ++i) {
            List<FocusNode> node = nodes[i];
            for (int j = 1; j < node.length; ++j) {
              if (node[j].hasFocus) {
                node[j - 1].requestFocus();
                return KeyEventResult.handled;
              }
            }
          }

        case LogicalKeyboardKey.arrowRight:
          for (int i = 0; i < nodes.length; ++i) {
            List<FocusNode> node = nodes[i];
            for (int j = 0; j < node.length - 1; ++j) {
              if (node[j].hasFocus) {
                node[j + 1].requestFocus();
                return KeyEventResult.handled;
              }
            }
          }
      }
    }
    return KeyEventResult.ignored;
  }

  List<Widget> createToolbar() {
    final tcontext = Translations.of(context);
    var settingConfig = SettingManager.getConfig();

    Size windowSize = MediaQuery.of(context).size;

    int maxCount = ((windowSize.width - 100) / 35).toInt();
    if (maxCount <= 0) {
      maxCount = 7;
    }

    List<Header> headerWidgets = [];
    if (settingConfig.uiScreen.homeShowMyProfiles) {
      headerWidgets.add(Header(tcontext.MyProfilesScreen.title,
          Icons.list_alt_outlined, onTapMyProfiles, _focusNodeMyProfiles));
    }
    if (settingConfig.uiScreen.homeShowAddProfile) {
      headerWidgets.add(Header(tcontext.addProfile, Icons.add_outlined,
          onTapAddProfile, _focusNodeAddProfile));
    }
    if (settingConfig.uiScreen.homeShowDNS) {
      headerWidgets.add(
          Header(tcontext.dns, Icons.dns_outlined, onTapDNS, _focusNodeDNS));
    }
    if (settingConfig.uiScreen.homeShowDeversion) {
      headerWidgets.add(Header(tcontext.diversion, Icons.alt_route_outlined,
          onTapDiversion, _focusNodeDeversion));
    }
    if (settingConfig.uiScreen.homeShowNetcheck) {
      headerWidgets.add(Header(tcontext.NetCheckScreen.title,
          Icons.network_check_outlined, onTapNetCheck, _focusNodeNetcheck));
    }
    if (settingConfig.uiScreen.homeShowSpeedtest) {
      headerWidgets.add(Header(tcontext.SettingsScreen.speedTest,
          Icons.speed_outlined, onTapSpeedTest, _focusNodeSpeedtest));
    }
    if (settingConfig.uiScreen.homeShowMyLink) {
      headerWidgets.add(Header(tcontext.SettingsScreen.myLink,
          Icons.link_outlined, onTapLink, _focusNodeMyLink));
    }
    if (settingConfig.uiScreen.homeShowAppleTV && PlatformUtils.isMobile()) {
      headerWidgets.add(Header(tcontext.appleTV, Icons.live_tv_outlined,
          onTapAppleTV, _focusNodeAppleTV));
    }
    List<Header> visibleWidgets = [];
    List<Header> moreWidgets = [];
    if (headerWidgets.length > maxCount) {
      visibleWidgets = headerWidgets.sublist(0, maxCount - 1);
      moreWidgets = headerWidgets.sublist(maxCount - 1);
    } else {
      visibleWidgets = headerWidgets;
    }
    List<Widget> widgets = [];
    _focusNodeToolbar.clear();
    for (var widget in visibleWidgets) {
      _focusNodeToolbar.add(widget.focus);
      widgets.add(Tooltip(
          message: widget.tooltip,
          child: InkWell(
              focusNode: widget.focus,
              onTap: widget.onTap,
              child: Stack(
                children: [
                  SizedBox(
                    width: 35,
                    height: 30,
                    child: Icon(
                      widget.iconData,
                      size: 26,
                    ),
                  ),
                ],
              ))));
    }
    if (moreWidgets.isNotEmpty) {
      _focusNodeToolbar.add(_focusNodeMore);
      widgets.add(Tooltip(
          message: tcontext.more,
          child: InkWell(
              focusNode: _focusNodeMore,
              onTap: () async {
                onTapToolbarMore(moreWidgets);
              },
              child: const Stack(
                children: [
                  SizedBox(
                    width: 35,
                    height: 30,
                    child: Icon(
                      Icons.more_vert_outlined,
                      size: 26,
                    ),
                  ),
                ],
              ))));
    }

    return widgets;
  }

  void onTapToolbarMore(List<Header> moreWidgets) {
    List<PopupMenuItem> items = [];
    for (var widget in moreWidgets) {
      items.add(
        PopupMenuItem(
            value: 0,
            child: Tooltip(
                message: widget.tooltip,
                child: InkWell(
                    onTap: widget.onTap,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 35,
                          height: 30,
                          child: Icon(
                            widget.iconData,
                            size: 26,
                          ),
                        ),
                      ],
                    )))),
      );
    }
    showMenu(
        context: context,
        position: const RelativeRect.fromLTRB(0.1, 0, 0, 0),
        items: items);
  }

  Widget createGroupTraffic(BuildContext context) {
    final tcontext = Translations.of(context);
    Size windowSize = MediaQuery.of(context).size;
    String groupid = _currentServer.groupid;
    const double height = 24 + 24 + 5;
    if (!_isStarted || groupid.isEmpty) {
      return const SizedBox(
        height: height,
      );
    }

    ServerConfigGroupItem? group;
    if (groupid == ServerManager.getUrltestGroupId()) {
      List<ServerConfigGroupItem> items = ServerManager.getConfig().items;

      if (_currentServerForSelector.now.isNotEmpty) {
        String newGroupId = "";
        for (var item in items) {
          if (!item.enable) {
            continue;
          }
          for (var server in item.servers) {
            if (server.tag == _currentServerForSelector.now) {
              newGroupId = item.groupid;
              break;
            }
          }
          if (newGroupId.isNotEmpty) {
            groupid = newGroupId;
            break;
          }
        }
      } else if (items.length == 1) {
        groupid = items[0].groupid;
      }
    }
    group = ServerManager.getByGroupId(groupid);
    if (group == null || groupid == ServerManager.getUrltestGroupId()) {
      return const SizedBox(
        height: height,
      );
    }
    if (group.traffic == null) {
      return SizedBox(
        height: height,
        child: Column(
          children: [
            Text(
              textAlign: TextAlign.center,
              group.remark,
              style: const TextStyle(
                fontSize: ThemeConfig.kFontSizeListSubItem,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Text(
            textAlign: TextAlign.center,
            group.remark,
            style: const TextStyle(
              fontSize: ThemeConfig.kFontSizeListSubItem,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          CommonWidget.createGroupTraffic(
              context,
              group.groupid,
              true,
              group.traffic,
              0,
              MainAxisAlignment.center,
              windowSize.width, (String groupId) {
            setState(() {});
          }, (String groupId, ReturnResult<SubscriptionTraffic> value) {
            if (!mounted) {
              return;
            }
            setState(() {});
            if (value.error != null) {
              if (value.error!.message.contains("405")) {
                ServerManager.reload(groupid).then((value) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {});
                  if (value != null) {
                    DialogUtils.showAlertDialog(
                        context, tcontext.updateFailed(p: value.message),
                        showCopy: true, showFAQ: true, withVersion: true);
                  }
                });
              } else {
                DialogUtils.showAlertDialog(
                    context, tcontext.updateFailed(p: value.error!.message),
                    showCopy: true, showFAQ: true, withVersion: true);
              }
            }
          })
        ],
      ),
    );
  }

  Widget createNetStatusChart(BuildContext context) {
    final tcontext = Translations.of(context);
    Size windowSize = MediaQuery.of(context).size;
    double width = windowSize.width <= kMaxWidth ? windowSize.width : kMaxWidth;
    double itemWidth = (width - 30) / 3;
    Color? color =
        Provider.of<Themes>(context, listen: false).getThemeIconColor(context);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        //memory_outlined
        SizedBox(
            width: itemWidth,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Icon(
                Icons.memory_outlined,
                size: 26,
                color: color,
              ),
              const SizedBox(width: 3),
              ValueListenableBuilder<String>(
                builder: _buildWithMemoryValue,
                valueListenable: _memory,
              ),
            ])),
        const SizedBox(
          width: 10,
        ),
        SizedBox(
            width: itemWidth,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                Icons.access_time_outlined,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 3),
              ValueListenableBuilder<String>(
                builder: _buildWithTimeValue,
                valueListenable: _startDuration,
              ),
            ])),
        const SizedBox(
          width: 10,
        ),
        SizedBox(
            width: itemWidth,
            child: Tooltip(
                message: tcontext.NetConnectionsScreen.title,
                child: InkWell(
                    focusNode: _focusNodeConnections,
                    onTap: () async {
                      await onTapNetConnections();
                    },
                    onLongPress: () async {
                      await onLongPressNetConnections();
                    },
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const Icon(Icons.monitor_outlined,
                              color: ThemeDefine.kColorGreenBright, size: 26),
                          const SizedBox(width: 3),
                          ValueListenableBuilder<String>(
                            builder: _buildWithConnnectionCountValue,
                            valueListenable: _connInboundCount,
                          ),
                        ])))),
      ]),
      const SizedBox(
        height: 5,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: itemWidth,
              child: Text(
                textAlign: TextAlign.center,
                tcontext.HomeScreen.trafficTotal,
                style: const TextStyle(
                  fontSize: ThemeConfig.kFontSizeListSubItem,
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.upload,
                  size: 15,
                  color: color,
                ),
                ValueListenableBuilder<String>(
                  builder: _buildWithTrafficValue,
                  valueListenable: _trafficUpTotal,
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.download,
                  size: 15,
                  color: color,
                ),
                ValueListenableBuilder<String>(
                  builder: _buildWithTrafficValue,
                  valueListenable: _trafficDownTotal,
                ),
              ],
            ),
          ]),
          const SizedBox(
            width: 10,
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: itemWidth,
              child: Text(
                textAlign: TextAlign.center,
                tcontext.HomeScreen.trafficProxy,
                style: const TextStyle(
                  fontSize: ThemeConfig.kFontSizeListSubItem,
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.upload,
                  size: 15,
                  color: color,
                ),
                ValueListenableBuilder<String>(
                  builder: _buildWithTrafficValue,
                  valueListenable: _trafficUpTotalProxy,
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.download,
                  size: 15,
                  color: color,
                ),
                ValueListenableBuilder<String>(
                  builder: _buildWithTrafficValue,
                  valueListenable: _trafficDownTotalProxy,
                ),
              ],
            ),
          ]),
          const SizedBox(
            width: 10,
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: itemWidth,
              child: Text(
                textAlign: TextAlign.center,
                tcontext.netSpeed,
                style: const TextStyle(
                  fontSize: ThemeConfig.kFontSizeListSubItem,
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.upload,
                  size: 15,
                  color: color,
                ),
                ValueListenableBuilder<String>(
                  builder: _buildWithTrafficValue,
                  valueListenable: _trafficUpSpeed,
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.download,
                  size: 15,
                  color: color,
                ),
                ValueListenableBuilder<String>(
                  builder: _buildWithTrafficValue,
                  valueListenable: _trafficDownSpeed,
                ),
              ],
            ),
          ]),
        ],
      )
    ]);
  }

  Widget _buildWithMemoryValue(
      BuildContext context, String value, Widget? child) {
    return SizedBox(
      child: Text(
        value,
        style: const TextStyle(fontSize: ThemeConfig.kFontSizeListSubItem),
      ),
    );
  }

  Widget _buildWithConnnectionCountValue(
      BuildContext context, String value, Widget? child) {
    return Text(
      value,
      style: const TextStyle(fontSize: ThemeConfig.kFontSizeListSubItem),
    );
  }

  Widget _buildWithTrafficValue(
      BuildContext context, String value, Widget? child) {
    return SizedBox(
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: ThemeConfig.kFontSizeListSubItem),
      ),
    );
  }

  Widget _buildWithTimeValue(
      BuildContext context, String value, Widget? child) {
    return SizedBox(
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: ThemeConfig.kFontSizeListItem),
      ),
    );
  }

  void _showNotify() {
    if (AppLifecycleStateNofityManager.isPaused()) {
      return;
    }
    if (_inAppNotificationsShowing) {
      return;
    }
    List<Notice> notices = NoticeManager.getNotices();
    NoticeItem? noticeItem;
    for (var notice in notices) {
      noticeItem = notice.getFirstUnread();
      if (noticeItem != null) {
        break;
      }
    }

    if (noticeItem == null) {
      return;
    }
    _inAppNotificationsShowing = true;
    final tcontext = Translations.of(context);
    InAppNotifications.show(
        title: tcontext.notice,
        duration: const Duration(seconds: 60),
        description: noticeItem.title,
        onTap: () {
          onTapNotice(noticeItem!);
        });
  }

  Future<void> moveToBackground() async {
    if (PlatformUtils.isMobile()) {
      await MoveToBackground.moveTaskToBack();
    } else if (PlatformUtils.isPC()) {
      await windowManager.hide();
    }
  }
}
