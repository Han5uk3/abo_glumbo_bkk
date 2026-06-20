import json
import glob
import os

paths = [
    '/Users/brandbik/Flutter/abo_glumbo_bkk/lib/l10n/app_en.arb',
    '/Users/brandbik/Flutter/abo_glumbo_bkk/lib/l10n/app_ur.arb',
    '/Users/brandbik/Flutter/abo_glumbo_technician_bbk/lib/l10n/app_en.arb',
    '/Users/brandbik/Flutter/abo_glumbo_technician_bbk/lib/l10n/app_ur.arb',
]

for path in paths:
    if os.path.exists(path):
        with open(path, 'r') as f:
            data = json.load(f)
        if "sarAmount" in data:
            data["sarAmount"] = "{amount} SAR"
        with open(path, 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Fixed {path}")

