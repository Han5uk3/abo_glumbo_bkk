import json
import os

apps = [
    r"c:\Hansuke\Work\abo_glumbo_bkk\lib\l10n",
    r"c:\Hansuke\Work\abo_glumbo_technician_bbk\lib\l10n"
]

translations = {
    "en": {"discountAppliesToInspectionFeeOnly": "Discount applies to the inspection fee only."},
    "ar": {"discountAppliesToInspectionFeeOnly": "ينطبق الخصم على رسوم الفحص فقط."},
    "ur": {"discountAppliesToInspectionFeeOnly": "رعایت صرف معائنہ فیس پر لاگو ہوتی ہے۔"}
}

for app in apps:
    for lang, trans in translations.items():
        file_path = os.path.join(app, f"app_{lang}.arb")
        if os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            data.update(trans)
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
