import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  late TextEditingController name, url, secret, public;
  late ServerImportController controller;
  late List<AgeKeyType> generated;
  late int revealed;

  setUp(() {
    controller = ServerImportController(loadSubscription: (_) async => null);
    name = controller.name;
    url = controller.url;
    secret = controller.secretKey;
    public = controller.publicKey;
    generated = [];
    revealed = 0;
  });

  tearDown(() => controller.close());

  Widget form({AgeKeyType? generatingKey, bool obscure = true}) =>
      BlocProvider.value(
        value: controller,
        child: BlocBuilder<ServerImportController, ServerImportPageState>(
          builder: (context, state) => SubscriptionFormView(
            supportText: 'Supported formats',
            nameLabel: 'Name',
            nameHint: 'Example Service',
            nameController: name,
            urlLabel: 'URL',
            urlController: url,
            urlHint: 'https://provider.example/subscription',
            urlHelper: 'HTTPS only',
            encryptionTitle: 'Encryption',
            ageProviderSupportTitle: 'Provider support required',
            ageProviderSupportDescription: 'Enter Age keys only when your provider supports encrypted subscriptions.',
            ageSecretKeyLabel: 'Age Secret Key',
            ageSecretKeyHint: 'AGE-SECRET-KEY-1...',
            ageSecretKeyController: secret,
            agePublicKeyLabel: 'Age Public Key',
            agePublicKeyHint: 'age1...',
            agePublicKeyController: public,
            obscureAgeSecretKey: obscure,
            revealAgeSecretKeyLabel: 'Reveal',
            hideAgeSecretKeyLabel: 'Hide',
            generateAgeKeyLabel: 'Generate',
            generateAgeX25519KeyLabel: 'X25519',
            generateAgeHybridKeyLabel: 'Hybrid (ML-KEM-768 + X25519)',
            clearAgeKeyLabel: 'Clear',
            onToggleAgeSecretKeyVisibility: () => revealed++,
            onGenerateAgeKey: generated.add,
            onClearAgeKey: controller.clearKeys,
            generatingAgeKeyType: generatingKey,
            hasAgeKeys: state.hasAgeKeys,
            ageExpanded: state.ageExpanded,
            onToggleAgeExpanded: controller.toggleAgeExpanded,
          ),
        ),
      );

  Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, appChild) =>
        ShadTheme(data: AppTheme.shad(Brightness.light), child: appChild!),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: child,
        ),
      ),
    ),
  );

  testWidgets('existing Age keys expose inline actions and busy guards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    secret.text = 'AGE-SECRET-KEY-1EXISTING';
    public.text = 'age1existing';
    await tester.pumpWidget(app(form()));
    await tester.pumpAndSettle();

    expect(find.text('Supported formats'), findsOneWidget);
    expect(find.text('HTTPS only'), findsOneWidget);
    expect(find.byType(ShadInput), findsNWidgets(4));
    expect(
      find.ancestor(
        of: find.byType(SubscriptionFormView),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('X25519'));
    await tester.tap(find.text('Hybrid (ML-KEM-768 + X25519)'));
    expect(generated, [AgeKeyType.x25519, AgeKeyType.hybrid]);
    await tester.tap(find.byTooltip('Reveal'));
    expect(revealed, 1);
    await tester.pumpWidget(app(form(obscure: false)));
    expect(find.byTooltip('Hide'), findsOneWidget);
    expect(
      tester
          .widgetList<ShadInput>(find.byType(ShadInput))
          .firstWhere((input) => input.controller == secret)
          .obscureText,
      isFalse,
    );

    await tester.pumpWidget(app(form(generatingKey: AgeKeyType.hybrid)));
    for (final button in [
      find.widgetWithText(OutlinedButton, 'X25519'),
      find.widgetWithText(OutlinedButton, 'Hybrid (ML-KEM-768 + X25519)'),
      find.widgetWithText(TextButton, 'Clear'),
    ]) {
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    }
    expect(find.byType(ButtonProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(OutlinedButton, 'Hybrid (ML-KEM-768 + X25519)'),
        matching: find.byType(ButtonProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(OutlinedButton, 'X25519'),
        matching: find.byType(ButtonProgressIndicator),
      ),
      findsNothing,
    );
    for (final input in tester.widgetList<ShadInput>(find.byType(ShadInput))) {
      expect(
        input.enabled,
        input.controller == name || input.controller == url,
      );
    }
    await tester.tap(find.byTooltip('Reveal'));
    expect(revealed, 2);
    expect(generated, hasLength(2));
    await tester.pumpWidget(app(form()));
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(secret.text, isEmpty);
    expect(public.text, isEmpty);
    expect(find.byType(ShadInput), findsNWidgets(4));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Clear'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('en'), Locale('fa')]) {
    testWidgets(
      'empty Age is collapsed and loaded keys expand on phone ($locale)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(form(), locale: locale));
        await tester.pumpAndSettle();
        expect(find.byType(ShadInput), findsNWidgets(2));
        expect(find.text('Provider support required'), findsOneWidget);
        expect(find.text('Age Secret Key'), findsNothing);
        expect(
          find.ancestor(
            of: find.byType(SubscriptionFormView),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );

        // Editing can load keys after the content has already mounted.
        secret.text = 'AGE-SECRET-KEY-1LOADED';
        expect(controller.state.hasAgeKeys, isTrue);
        expect(controller.state.ageExpanded, isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(ShadInput), findsNWidgets(4));
        for (final controller in [url, secret, public]) {
          final input = find.byWidgetPredicate(
            (widget) => widget is ShadInput && widget.controller == controller,
          );
          final editable = find.descendant(
            of: input,
            matching: find.byType(EditableText),
          );
          expect(
            Directionality.of(tester.element(editable)),
            TextDirection.ltr,
          );
        }
        await tester.ensureVisible(find.text('Clear'));
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();
        expect(find.byType(ShadInput), findsNWidgets(4));
        await tester.ensureVisible(find.text('Encryption'));
        await tester.tap(find.text('Encryption'));
        await tester.pumpAndSettle();
        expect(find.byType(ShadInput), findsNWidgets(2));

        // Either key can reveal a loaded draft; changing a nonempty key does not
        // override a later manual collapse.
        public.text = 'age1loaded';
        await tester.pumpAndSettle();
        expect(find.byType(ShadInput), findsNWidgets(4));
        await tester.tap(find.text('Encryption'));
        await tester.pumpAndSettle();
        public.text = 'age1changed';
        await tester.pumpAndSettle();
        expect(find.byType(ShadInput), findsNWidgets(2));
        expect(public.text, 'age1changed');
        await tester.tap(find.text('Encryption'));
        await tester.pumpAndSettle();
        expect(find.byType(ShadInput), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
