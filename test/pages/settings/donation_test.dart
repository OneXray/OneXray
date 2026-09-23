import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/constants/donation.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/settings/donation/page.dart';
import 'package:onexray/pages/shared/widgets/page_action_bar.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  Widget wrap(BuildContext context, Widget? child) => ShadTheme(
    data: AppTheme.shad(Brightness.light),
    child: ShadToaster(child: child ?? const SizedBox.shrink()),
  );

  Widget app(Locale locale) => MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalePolicy.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: wrap,
    home: const DonationPage(),
  );

  for (final locale in const [
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ru'),
    Locale('fa'),
  ]) {
    for (final size in const [Size(320, 640), Size(1200, 900)]) {
      testWidgets('donation layout and copy ${locale.toLanguageTag()} $size', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(app(locale));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DonationPage)),
        )!;
        expect(find.text(DonationInfo.network), findsOneWidget);
        expect(find.text(DonationInfo.assets), findsOneWidget);
        final address = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );
        expect(address.data, 'A7srSnpozZDHVvm863xnCbtSr8DRxMCd8dJi3uS9MGcj');
        expect(address.textDirection, TextDirection.ltr);
        expect(address.maxLines, isNull);
        final addressRect = tester.getRect(find.byType(SelectableText));
        final addressCardRect = tester.getRect(
          find
              .ancestor(
                of: find.byType(SelectableText),
                matching: find.byType(ShadCard),
              )
              .first,
        );
        expect(
          addressRect.left - addressCardRect.left,
          greaterThanOrEqualTo(16),
        );
        expect(
          addressCardRect.right - addressRect.right,
          greaterThanOrEqualTo(16),
        );
        expect(addressRect.top - addressCardRect.top, greaterThanOrEqualTo(16));
        expect(
          addressCardRect.bottom - addressRect.bottom,
          greaterThanOrEqualTo(16),
        );
        final detailsRect = tester.getRect(find.byType(ShadCard).first);
        expect(addressCardRect.left, detailsRect.left);
        expect(addressCardRect.right, detailsRect.right);
        expect(find.byType(PageActionBar), findsNothing);
        expect(tester.takeException(), isNull);

        final copy = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == l10n.donationCopyAddress,
        );
        expect(copy.hitTestable(), findsOneWidget);
        final copyRect = tester.getRect(copy);
        expect(addressCardRect.contains(copyRect.topLeft), isTrue);
        expect(addressCardRect.contains(copyRect.bottomRight), isTrue);
        expect(copyRect.center.dy, closeTo(addressRect.center.dy, 0.01));
        if (locale.languageCode == 'fa') {
          expect(addressRect.left - copyRect.right, closeTo(12, 0.01));
        } else {
          expect(copyRect.left - addressRect.right, closeTo(12, 0.01));
        }
        await tester.tap(copy);
        await tester.pumpAndSettle();
        expect(copied, DonationInfo.address);
        expect(find.text(l10n.donationAddressCopied), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }

  testWidgets('copy waits locally and reports clipboard errors', (
    tester,
  ) async {
    final result = Completer<void>();
    var copies = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copies++;
          await result.future;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    final copy = find.byType(IconButton);
    await tester.tap(copy);
    await tester.pump();
    expect(tester.widget<IconButton>(copy).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    result.completeError(
      PlatformException(code: 'unavailable', message: 'Clipboard unavailable'),
    );
    await tester.pumpAndSettle();
    expect(copies, 1);
    expect(tester.widget<IconButton>(copy).onPressed, isNotNull);
    expect(find.text('Donation address copied'), findsNothing);
    expect(find.textContaining('Clipboard unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('donation is a detail route inside the current tab', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pushScoped(AppPageDestination.donation),
              child: const Text('Open donation'),
            ),
          ),
          routes: buildScopedPageRoutes(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalePolicy.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: wrap,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open donation'));
    await tester.pumpAndSettle();
    expect(
      GoRouterState.of(tester.element(find.byType(DonationPage))).uri.path,
      '/settings/donation',
    );
    expect(find.byType(DonationPage), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('Open donation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
