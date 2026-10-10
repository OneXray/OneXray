# Store badges

Official localized download artwork, stored locally and used without modifying the images. `en`, `zh`, and `ru` correspond to the English, Simplified Chinese, and Russian READMEs.

| Store | Artwork source | Language codes |
| --- | --- | --- |
| App Store | `https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/{locale}?size=250x83` | `en-us`, `zh-cn`, `ru-ru` |
| Google Play | `https://play.google.com/intl/en_us/badges/static/images/badges/{locale}_badge_web_generic.png` | `en`, `zh-cn`, `ru` |
| Microsoft Store | `https://get.microsoft.com/images/{locale}%20dark.svg` | `en-us`, `zh-cn`, `ru` |

App Store and Microsoft Store images are displayed at 48 px high. The Google Play PNGs include different amounts of official surrounding clear space: display English at 72 px high and Chinese/Russian at 64 px high so their visible badges have a comparable height. Keep the aspect ratio and clear space when reusing these images.

Source references: [Apple marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/), [Google Play badges](https://play.google.com/intl/en_us/badges/), and [Microsoft's HTML-only badge documentation](https://github.com/microsoft/app-store-badge#html-only). Store names, logos, and badge artwork belong to their respective owners.
