import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

const double _bottomPaddingForButton = 150.0;
const double _buttonHeight = 56.0;
const double _buttonWidth = 200.0;
const double _pagePadding = 16.0;
const double _pageBreakpoint = 768.0;
const double _heroImageHeight = 250.0;
const Color _lightThemeShadowColor = Color(0xFFE4E4E4);
const Color _darkThemeShadowColor = Color(0xFF121212);
const Color _darkSabGradientColor = Color(0xFF313236);
final materialColorsInGrid = allMaterialColors.take(20).toList();
final materialColorsInSliverList = allMaterialColors.sublist(20, 25);

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _isLightTheme = true;

  @override
  Widget build(BuildContext context) {
    SliverWoltModalSheetPage page1(
        BuildContext modalSheetContext, TextTheme textTheme) {
      return WoltModalSheetPage(
        hasSabGradient: false,
        stickyActionBar: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: Navigator.of(modalSheetContext).pop,
                child: const SizedBox(
                  height: _buttonHeight,
                  width: double.infinity,
                  child: Center(child: Text('Cancel')),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: WoltModalSheet.of(modalSheetContext).showNext,
                child: const SizedBox(
                  height: _buttonHeight,
                  width: double.infinity,
                  child: Center(child: Text('Next page')),
                ),
              ),
            ],
          ),
        ),
        topBarTitle: Text('Pagination', style: textTheme.titleSmall),
        isTopBarLayerAlwaysVisible: true,
        trailingNavBarWidget: IconButton(
          padding: const EdgeInsets.all(_pagePadding),
          icon: const Icon(Icons.close),
          onPressed: Navigator.of(modalSheetContext).pop,
        ),
        child: const Padding(
            padding: EdgeInsets.fromLTRB(
              _pagePadding,
              _pagePadding,
              _pagePadding,
              _bottomPaddingForButton,
            ),
            child: Text(
              '''
Page 0.
''',
            )),
      );
    }

    SliverWoltModalSheetPage page2(
        BuildContext modalSheetContext, TextTheme textTheme) {
      return SliverWoltModalSheetPage(
        pageTitle: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Text(
            'page 1',
            style:
                textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        leadingNavBarWidget: IconButton(
          padding: const EdgeInsets.all(_pagePadding),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: WoltModalSheet.of(modalSheetContext).showPrevious,
        ),
        trailingNavBarWidget: IconButton(
          padding: const EdgeInsets.all(_pagePadding),
          icon: const Icon(Icons.close),
          onPressed: Navigator.of(modalSheetContext).pop,
        ),
        stickyActionBar: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: ElevatedButton(
            onPressed: Navigator.of(modalSheetContext).pop,
            child: const SizedBox(
              height: _buttonHeight,
              width: double.infinity,
              child: Center(child: Text('Close')),
            ),
          ),
        ),
        mainContentSliversBuilder: (context) => [
          SliverPadding(
            padding: EdgeInsets.only(bottom: _bottomPaddingForButton),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(_pagePadding),
                child: InkWell(
                    child: Text('Wolt Sheet Index 0'),
                    onTap: () =>
                        WoltModalSheet.of(modalSheetContext).showAtIndex(0)),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: _bottomPaddingForButton),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(_pagePadding),
                child: InkWell(
                    child: Text('Wolt Sheet Index 2'),
                    onTap: () =>
                        WoltModalSheet.of(modalSheetContext).showAtIndex(2)),
              ),
            ),
          ),
        ],
      );
    }

    SliverWoltModalSheetPage page3(
        BuildContext modalSheetContext, TextTheme textTheme) {
      return SliverWoltModalSheetPage(
        pageTitle: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Text(
            'page 2',
            style:
                textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        leadingNavBarWidget: IconButton(
          padding: const EdgeInsets.all(_pagePadding),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: WoltModalSheet.of(modalSheetContext).showPrevious,
        ),
        trailingNavBarWidget: IconButton(
          padding: const EdgeInsets.all(_pagePadding),
          icon: const Icon(Icons.close),
          onPressed: Navigator.of(modalSheetContext).pop,
        ),
        stickyActionBar: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: ElevatedButton(
            onPressed: Navigator.of(modalSheetContext).pop,
            child: const SizedBox(
              height: _buttonHeight,
              width: double.infinity,
              child: Center(child: Text('Close')),
            ),
          ),
        ),
        mainContentSliversBuilder: (context) => [
          SliverPadding(
            padding: EdgeInsets.only(bottom: _bottomPaddingForButton),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(_pagePadding),
                child: InkWell(
                    child: Text('Wolt Sheet Index 0'),
                    onTap: () =>
                        WoltModalSheet.of(modalSheetContext).showAtIndex(0)),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: _bottomPaddingForButton),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(_pagePadding),
                child: InkWell(
                    child: Text('Wolt Sheet Index 1'),
                    onTap: () =>
                        WoltModalSheet.of(modalSheetContext).showAtIndex(1)),
              ),
            ),
          ),
        ],
      );
    }

    return MaterialApp(
      themeMode: _isLightTheme ? ThemeMode.light : ThemeMode.dark,
      theme: ThemeData.light().copyWith(
        extensions: const <ThemeExtension>[
          WoltModalSheetThemeData(
            heroImageHeight: _heroImageHeight,
            topBarShadowColor: _lightThemeShadowColor,
            modalBarrierColor: Colors.black54,
            mainContentScrollPhysics: ClampingScrollPhysics(),
          ),
        ],
      ),
      darkTheme: ThemeData.dark().copyWith(
        extensions: const <ThemeExtension>[
          WoltModalSheetThemeData(
            topBarShadowColor: _darkThemeShadowColor,
            modalBarrierColor: Colors.white12,
            sabGradientColor: _darkSabGradientColor,
            mainContentScrollPhysics: ClampingScrollPhysics(),
          ),
        ],
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Light Theme'),
                    Padding(
                      padding: const EdgeInsets.all(_pagePadding),
                      child: Switch(
                        value: !_isLightTheme,
                        onChanged: (_) =>
                            setState(() => _isLightTheme = !_isLightTheme),
                      ),
                    ),
                    const Text('Dark Theme'),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    WoltModalSheet.show<void>(
                      context: context,
                      pageListBuilder: (modalSheetContext) {
                        final textTheme = Theme.of(context).textTheme;
                        return [
                          page1(modalSheetContext, textTheme),
                          page2(modalSheetContext, textTheme),
                          page3(modalSheetContext, textTheme),
                        ];
                      },
                      modalTypeBuilder: (context) {
                        final size = MediaQuery.sizeOf(context).width;
                        if (size < _pageBreakpoint) {
                          return _isLightTheme
                              ? const WoltBottomSheetType()
                              : const WoltBottomSheetType().copyWith(
                                  shapeBorder: const BeveledRectangleBorder(),
                                );
                        } else {
                          return _isLightTheme
                              ? const WoltDialogType()
                              : const WoltDialogType().copyWith(
                                  shapeBorder: const BeveledRectangleBorder(),
                                );
                        }
                      },
                      onModalDismissedWithBarrierTap: () {
                        debugPrint('Closed modal sheet with barrier tap');
                        Navigator.of(context).pop();
                      },
                    );
                  },
                  child: const SizedBox(
                    height: _buttonHeight,
                    width: _buttonWidth,
                    child: Center(child: Text('Show Modal Sheet')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ColorTile extends StatelessWidget {
  final Color color;

  const ColorTile({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      height: 600,
      child: Center(
        child: Text(
          color.toString(),
          style: TextStyle(
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

List<Color> get allMaterialColors {
  List<Color> allMaterialColorsWithShades = [];

  for (MaterialColor color in Colors.primaries) {
    allMaterialColorsWithShades.add(color.shade100);
    allMaterialColorsWithShades.add(color.shade200);
    allMaterialColorsWithShades.add(color.shade300);
    allMaterialColorsWithShades.add(color.shade400);
    allMaterialColorsWithShades.add(color.shade500);
    allMaterialColorsWithShades.add(color.shade600);
    allMaterialColorsWithShades.add(color.shade700);
    allMaterialColorsWithShades.add(color.shade800);
    allMaterialColorsWithShades.add(color.shade900);
  }
  return allMaterialColorsWithShades;
}
