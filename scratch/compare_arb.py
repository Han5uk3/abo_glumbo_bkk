import json

def get_keys(path):
    with open(path, 'r') as f:
        data = json.load(f)
        return set(data.keys())

en_keys = get_keys('/Users/brandbik/Flutter/abo_glumbo_bkk/lib/l10n/app_en.arb')
ar_keys = get_keys('/Users/brandbik/Flutter/abo_glumbo_bkk/lib/l10n/app_ar.arb')
ur_keys = get_keys('/Users/brandbik/Flutter/abo_glumbo_bkk/lib/l10n/app_ur.arb')

print(f"Missing in AR: {en_keys - ar_keys}")
print(f"Missing in UR: {en_keys - ur_keys}")
