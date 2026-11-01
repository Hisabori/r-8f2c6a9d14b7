import 'native_modules.dart';
import 'app_theme.dart';
import 'glass_surface.dart';
import 'lens_navigation.dart';
import 'bark_history.dart';
import 'live_bark_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bark_home.dart' as bark;
import 'transit/main.dart' as transit;

void main() {
  runApp(const BarkApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NativeModules.ready();
  });
  if (const bool.fromEnvironment('STARTUP_SMOKE')) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await const MethodChannel(
        'com.railtime/alerts',
      ).invokeMethod('startupReady');
    });
  }
}

class BarkApp extends StatelessWidget {
  const BarkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Care Suite',
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(brightness: Brightness.dark),
    themeMode: ThemeMode.light,
    home: const FeatureHome(),
  );
}

class FeatureHome extends StatelessWidget {
  Future<void> native(BuildContext context, String module) async {
    try {
      final opened = await NativeModules.open(module);
      if (context.mounted && !opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('iPhone 통합 호스트가 준비되지 않았거나 다른 화면이 열려 있습니다.'),
          ),
        );
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네이티브 화면을 열지 못했습니다. 현재 작업을 닫고 다시 시도하세요.'),
          ),
        );
      }
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('통합 iOS 빌드에서 사용할 수 있습니다.')),
        );
      }
    }
  }

  const FeatureHome({super.key});
  void open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return CareSummarySurface(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          title: const Text(
            '요약',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: CareLensNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              if (index == 1) native(context, 'health');
              if (index == 2) open(context, const bark.Home());
              if (index == 3) native(context, 'crypto');
              if (index == 4) open(context, const transit.Home());
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '오늘',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                label: '온케어',
              ),
              NavigationDestination(
                icon: Icon(Icons.pets_outlined),
                label: '강아지',
              ),
              NavigationDestination(icon: Icon(Icons.show_chart), label: '투자'),
              NavigationDestination(
                icon: Icon(Icons.directions_transit_outlined),
                label: '이동',
              ),
            ],
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  CareLensNavigationBar.contentInset(context),
                ),
                children: [
                  Text(
                    '${now.month}월 ${now.day}일 · 오늘도 함께',
                    style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '나를 돌보는 일상,\n함께하는 하루',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '건강 · 반려생활 · 리서치를 차분하게 이어가요.',
                    style: TextStyle(fontSize: 17, color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  CareGlassSurface(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '오늘의 작은 돌봄',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '건강과 투약을 챙기고, 반려생활과 투자 기록도 편하게 살펴보세요.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: () => native(context, 'health'),
                            icon: const Icon(Icons.favorite_outline),
                            label: const Text('건강과 투약 살펴보기'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => native(context, 'crypto'),
                            icon: const Icon(Icons.show_chart),
                            label: const Text('투자와 리서치 살펴보기'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('새로운 통합 앱'),
                                content: const Text(
                                  '기존 앱의 기기 내 기록과 토큰은 자동으로 읽거나 옮기지 않습니다. 온케어 가져오기 기능을 사용하고 거래 서버는 통합 앱에서 다시 연결하세요. 강아지 소리 분석은 검증된 감정 번역이나 진단이 아닙니다.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('확인'),
                                  ),
                                ],
                              ),
                            ),
                            child: const Text('기록 가져오기 · 연결 안내'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CareGlassSurface(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '나에게 맞춘 오늘',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.favorite_border_rounded,
                                size: 22,
                                color: Color(0xff138477),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '강아지의 소리를 이해하고,\n외출은 여유 있게 준비해요.',
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.5,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    open(context, const bark.Home()),
                                icon: const Icon(Icons.mic_none_rounded),
                                label: const Text('소리 기록하기'),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    open(context, const transit.Home()),
                                icon: const Icon(Icons.near_me_outlined),
                                label: const Text('나갈 시간 확인'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '빠른 기록',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth >= 350 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 18
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.pets_outlined,
                              '소리 분석',
                              '녹음 · 품종별 기록',
                              const bark.Home(),
                              const Color(0xff138477),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.directions_transit_rounded,
                              '길찾기',
                              '지도 · 경로 · 출발 알림',
                              const transit.Home(),
                              const Color(0xff387df5),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.insights_outlined,
                              '지난 분석',
                              '기록과 패턴 돌아보기',
                              const BarkHistoryPage(),
                              const Color(0xff8c73d9),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.hearing_rounded,
                              '실시간 분석',
                              '듣는 동안 바로 확인',
                              const LiveBarkPage(),
                              const Color(0xff17a89c),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.phonelink_lock_outlined,
                            color: Color(0xff138477),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '내 기기에서 안전하게',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '소리 분석은 기기 안에서 처리해요. 교통 정보 조회에는 인터넷이 필요해요.',
                                  style: TextStyle(color: muted, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String detail,
    Widget page,
    Color accent,
  ) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => open(context, page),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
