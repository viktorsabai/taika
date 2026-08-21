# Taika economics sources and assumptions

## Observed benchmarks

- RevenueCat State of Subscription Apps 2025: dataset of 75,000 subscription apps and $10B+ tracked revenue; median download-to-trial conversion cited as 6.2%, P90 20.3%; top 5% of newly launched apps reached $8,880 after year one versus bottom 25% no more than $19; nearly 30% of annual subscriptions canceled in first month; cheap annual plans retained up to 36% after a year; report is not education-only and is subject to selection bias because it covers RevenueCat apps. Source: https://www.revenuecat.com/state-of-subscription-apps-2025
- RevenueCat State of Subscription Apps 2026: over 115,000 apps, $16B revenue, more than one billion transactions; includes active subscription-revenue apps meeting minimum install/revenue thresholds, so it is not a random sample of all App Store apps. Source: https://www.revenuecat.com/state-of-subscription-apps
- Business of Apps Education App Benchmarks 2026: education app store-view-to-download conversion cited as 18.1% on iOS and 34.4% on Google Play; D30 retention cited as 2%; average education subscription cost cited as $8.13/month and $56.09/year; source covers only a limited set of apps and should be used directionally, not as a Taika forecast. Source: https://www.businessofapps.com/data/education-app-benchmarks/
- Appodeal Benchmarks: eCPM and impressions/user vary by country, platform, format, category and period; data is based on billions of anonymized ad impressions and is intended to be filtered rather than treated as one global number. Source: https://appodeal.com/blog/mobile-ecpm-report-app-ad-monetization-worldwide-performance/
- Apple Small Business Program: new developers and developers within the eligibility threshold can qualify for 15% commission on paid apps and in-app purchases; eligibility is based on proceeds and associated accounts. Source: https://developer.apple.com/app-store/small-business-program/
- Apple TestFlight: builds can be tested for up to 90 days; external testing can include up to 10,000 testers and may require review, while internal testing is for App Store Connect users. Source: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/

## Taika pricing currently in repository

- Monthly: 349 THB gross.
- Annual: 1,690 THB gross.
- Lifetime: 3,990 THB gross.
- Intro trial: 7 days.
- Working FX for illustrative conversion only: 35 THB = 1 USD. Replace with App Store Connect proceeds reports or actual accounting FX.

## Scenario assumptions used in the first model

These are not market facts. They are explicit planning assumptions designed to give an order of magnitude until TestFlight data arrives.

| Scenario | MAU | Paid rate | New installs/month | Ad impressions/free user/day | Blended gross ad eCPM |
|---|---:|---:|---:|---:|---:|
| Pessimistic | 3,000 | 1% | 500 | 0.10 | $5 |
| Realistic | 30,000 | 3% | 5,000 | 0.25 | $8 |
| Optimistic | 300,000 | 5% | 50,000 | 0.50 | $12 |

For subscription mix, the model assumes 65% monthly, 30% annual and 5% lifetime among active paid base. Lifetime is amortized over 24 months for a monthly run-rate comparison. Subscription proceeds are gross price × 85%; this excludes taxes, refunds, chargebacks, currency effects and RevenueCat/other service fees. Ad proceeds are modeled as gross eCPM × 80% to allow for fill/mediation/measurement leakage; actual network proceeds may differ.
