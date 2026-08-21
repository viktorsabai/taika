from dataclasses import dataclass

@dataclass
class Scenario:
    name: str
    mau: int
    paid_rate: float
    impressions_per_free_user_day: float
    blended_ecpm_usd: float
    monthly_installs: int

prices = {
    'monthly': 349.0,
    'annual_monthly_equiv': 1690.0 / 12.0,
    'lifetime_monthly_equiv': 3990.0 / 24.0,
}
# Hypothetical mix of active paid base; lifetime is amortized over 24 months.
weighted_gross_thb = 0.65*prices['monthly'] + 0.30*prices['annual_monthly_equiv'] + 0.05*prices['lifetime_monthly_equiv']
net_subscription_thb_per_payer_month = weighted_gross_thb * 0.85
fx_thb_usd = 35.0
ad_net_factor = 0.80  # network/mediation/other leakage; eCPM here is gross benchmark assumption

scenarios = [
    Scenario('Пессимистичный', 3000, 0.01, 0.10, 5.0, 500),
    Scenario('Реалистичный', 30000, 0.03, 0.25, 8.0, 5000),
    Scenario('Оптимистичный', 300000, 0.05, 0.50, 12.0, 50000),
]

print('Weighted gross THB/payer/month', weighted_gross_thb)
print('Net subscription THB/payer/month', net_subscription_thb_per_payer_month)
print()
print('name,mau,installs_month,paid_users,subscription_thb_day,free_users,ad_impressions_day,ad_thb_day,total_thb_day,total_usd_day')
for s in scenarios:
    paid = round(s.mau*s.paid_rate)
    sub_day = paid*net_subscription_thb_per_payer_month/30.4375
    free = s.mau-paid
    impressions_day = free*s.impressions_per_free_user_day
    ad_usd_day = impressions_day/1000*s.blended_ecpm_usd*ad_net_factor
    ad_thb_day = ad_usd_day*fx_thb_usd
    total = sub_day+ad_thb_day
    print(f'{s.name},{s.mau},{s.monthly_installs},{paid},{sub_day:.2f},{free},{impressions_day:.0f},{ad_thb_day:.2f},{total:.2f},{total/fx_thb_usd:.2f}')

print('\nGross-to-net examples for one new subscriber (before tax/refunds):')
for label, gross in [('monthly',349),('annual',1690),('lifetime',3990)]:
    print(label, gross, gross*0.85, gross/fx_thb_usd, gross*0.85/fx_thb_usd)
