import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

// Constants
const double _bottomPaddingForButton = 150.0;
const double _buttonHeight = 56.0;
const double _buttonWidth = 200.0;
const double _pagePadding = 16.0;
const double _pageBreakpoint = 768.0;
const double _heroImageHeight = 250.0;
const Color _lightThemeShadowColor = Color(0xFFE4E4E4);
const Color _darkThemeShadowColor = Color(0xFF121212);
const Color _darkSabGradientColor = Color(0xFF313236);

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _isLightTheme = true;

  @override
  Widget build(BuildContext context) {
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
                _buildThemeToggle(),
                const SizedBox(height: 20),
                _buildShowModalButton(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Light Theme'),
        Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Switch(
            value: !_isLightTheme,
            onChanged: (_) => setState(() => _isLightTheme = !_isLightTheme),
          ),
        ),
        const Text('Dark Theme'),
      ],
    );
  }

  Widget _buildShowModalButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showModalSheet(context),
      child: const SizedBox(
        height: _buttonHeight,
        width: _buttonWidth,
        child: Center(child: Text('Show Modal Sheet')),
      ),
    );
  }

  void _showModalSheet(BuildContext context) {
    WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        final textTheme = Theme.of(context).textTheme;
        return [_buildPageA(modalSheetContext, textTheme)];
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
  }

  // Page Builders
  SliverWoltModalSheetPage _buildPageA(
      BuildContext modalSheetContext, TextTheme textTheme) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      stickyActionBar: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => WoltModalSheet.of(modalSheetContext)
                  .pushPage(_buildPageB(modalSheetContext, textTheme)),
              child: const SizedBox(
                height: _buttonHeight,
                width: double.infinity,
                child: Center(child: Text('Next step B')),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: Navigator.of(modalSheetContext).pop,
              child: const SizedBox(
                height: _buttonHeight,
                width: double.infinity,
                child: Center(child: Text('Cancel')),
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
        child: Text('Step A.'),
      ),
    );
  }

  SliverWoltModalSheetPage _buildPageB(
      BuildContext modalSheetContext, TextTheme textTheme) {
    return SliverWoltModalSheetPage(
      pageTitle: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: Text(
          'Stap B',
          style: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(_pagePadding),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: WoltModalSheet.of(modalSheetContext).popPage,
      ),
      trailingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(_pagePadding),
        icon: const Icon(Icons.close),
        onPressed: Navigator.of(modalSheetContext).pop,
      ),
      stickyActionBar: Container(
        child: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
            ),
            onPressed: Navigator.of(modalSheetContext).pop,
            child: const SizedBox(
              height: _buttonHeight,
              width: double.infinity,
              child: Center(child: Text('Close')),
            ),
          ),
        ),
      ),
      mainContentSliversBuilder: (context) => [
        _buildContentItem(
          context,
          'Next step C',
              () => WoltModalSheet.of(modalSheetContext)
              .pushPage(_buildPageC(modalSheetContext, textTheme)),
        ),
        _buildContentItem(
          context,
          'Next step D',
              () => WoltModalSheet.of(modalSheetContext)
              .pushPage(_buildPageD(modalSheetContext, textTheme)),
          bottomPadding: 80,
        ),
      ],
    );
  }

  SliverWoltModalSheetPage _buildPageC(
      BuildContext modalSheetContext, TextTheme textTheme) {
    return SliverWoltModalSheetPage(
      pageTitle: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: Text(
          'Stap C',
          style: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(_pagePadding),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: WoltModalSheet.of(modalSheetContext).popPage,
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
        _buildContentItem(context, 'last', null, bottomPadding: 100),
      ],
    );
  }

  SliverWoltModalSheetPage _buildPageD(
      BuildContext modalSheetContext, TextTheme textTheme) {
    return SliverWoltModalSheetPage(
      pageTitle: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: Text(
          'Stap D',
          style: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(_pagePadding),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: WoltModalSheet.of(modalSheetContext).popPage,
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
        _buildContentItem(
          context,
          'Next step E',
              () => WoltModalSheet.of(modalSheetContext)
              .pushPage(_buildPageE(modalSheetContext, textTheme)),
        ),
        _buildContentItem(
          context,
          'Next page F',
              () => WoltModalSheet.of(modalSheetContext)
              .pushPage(_buildPageF(modalSheetContext, textTheme)),
          bottomPadding: 80,
        ),
      ],
    );
  }

  SliverWoltModalSheetPage _buildPageE(
      BuildContext modalSheetContext, TextTheme textTheme) {
    return SliverWoltModalSheetPage(
      pageTitle: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: Text(
          'Stap E',
          style: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(_pagePadding),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: WoltModalSheet.of(modalSheetContext).popPage,
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
        _buildContentItem(context, 'last', null, bottomPadding: 100),
      ],
    );
  }

  SliverWoltModalSheetPage _buildPageF(
      BuildContext modalSheetContext, TextTheme textTheme) {
    return SliverWoltModalSheetPage(
      pageTitle: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: Text(
          'Stap F',
          style: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(_pagePadding),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: WoltModalSheet.of(modalSheetContext).popPage,
      ),
      trailingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(_pagePadding),
        icon: const Icon(Icons.close),
        onPressed: Navigator.of(modalSheetContext).pop,
      ),
      stickyActionBar: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
          ),
          onPressed: Navigator.of(modalSheetContext).pop,
          child: const SizedBox(
            height: _buttonHeight,
            width: double.infinity,
            child: Center(child: Text('Close')),
          ),
        ),
      ),
      mainContentSliversBuilder: (context) => [
        _buildContentItem(context, 'last', null, bottomPadding: 100),
      ],
    );
  }

  // Helper method to build content items
  SliverPadding _buildContentItem(
      BuildContext context,
      String text,
      VoidCallback? onTap, {
        double bottomPadding = 0,
      }) {
    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      sliver: SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(_pagePadding),
          child: InkWell(
            onTap: onTap,
            child: Card(
              child: SizedBox(
                  height: 50, child: Center(child: Text(text))),
            ),
          ),
        ),
      ),
    );
  }
}