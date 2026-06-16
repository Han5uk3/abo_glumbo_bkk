const fs = require('fs');
const path = require('path');

const bkkPath = 'c:\\Hansuke\\Work\\abo_glumbo_bkk\\lib';
const techPath = 'c:\\Hansuke\\Work\\abo_glumbo_technician_bbk\\lib';

const arbPaths = {
    bkk: {
        en: path.join(bkkPath, 'l10n', 'app_en.arb'),
        ar: path.join(bkkPath, 'l10n', 'app_ar.arb'),
        ur: path.join(bkkPath, 'l10n', 'app_ur.arb')
    },
    tech: {
        en: path.join(techPath, 'l10n', 'app_en.arb'),
        ar: path.join(techPath, 'l10n', 'app_ar.arb'),
        ur: path.join(techPath, 'l10n', 'app_ur.arb')
    }
};

const replacements = {
    bkk: [
        {
            file: path.join(bkkPath, 'pages', 'bookings', 'book_service_page.dart'),
            items: [
                { old: 'Loading customer data, please wait...', key: 'loadingCustomerData', en: 'Loading customer data, please wait...', ar: 'جاري تحميل بيانات العميل، يرجى الانتظار...', ur: 'کسٹمر کا ڈیٹا لوڈ ہو رہا ہے، براہ کرم انتظار کریں...' },
                { old: "Failed to create booking request", key: 'failedToCreateBookingRequest', en: 'Failed to create booking request', ar: 'فشل في إنشاء طلب الحجز', ur: 'بکنگ کی درخواست بنانے میں ناکام' },
                { old: 'Please wait for customer data to load or select a date', key: 'pleaseWaitCustomerDataLoad', en: 'Please wait for customer data to load or select a date', ar: 'يرجى الانتظار لتحميل بيانات العميل أو تحديد تاريخ', ur: 'براہ کرم کسٹمر کا ڈیٹا لوڈ ہونے کا انتظار کریں یا تاریخ منتخب کریں' },
            ]
        },
        {
            file: path.join(bkkPath, 'services', 'auth_services.dart'),
            items: [
                { old: 'This account is not registered as a customer.', key: 'accountNotRegisteredCustomer', en: 'This account is not registered as a customer.', ar: 'هذا الحساب غير مسجل كعميل.', ur: 'یہ اکاؤنٹ بطور کسٹمر رجسٹرڈ نہیں ہے۔' }
            ]
        },
        {
            file: path.join(bkkPath, 'sheets', 'payment.dart'),
            items: [
                { old: 'Apple Pay Not Available', key: 'applePayNotAvailable', en: 'Apple Pay Not Available', ar: 'Apple Pay غير متوفر', ur: 'ایپل پے دستیاب نہیں ہے' },
                { old: 'Apple Pay is not available on this device.', key: 'applePayNotAvailableDevice', en: 'Apple Pay is not available on this device.', ar: 'Apple Pay غير متوفر على هذا الجهاز.', ur: 'ایپل پے اس ڈیوائس پر دستیاب نہیں ہے۔' },
                { old: 'Choose Another Payment Method', key: 'chooseAnotherPaymentMethod', en: 'Choose Another Payment Method', ar: 'اختر طريقة دفع أخرى', ur: 'ادائیگی کا دوسرا طریقہ منتخب کریں' },
                { old: 'Try Another Payment Method', key: 'tryAnotherPaymentMethod', en: 'Try Another Payment Method', ar: 'جرب طريقة دفع أخرى', ur: 'ادائیگی کا دوسرا طریقہ آزمائیں' },
                { old: 'Apple Pay Error', key: 'applePayError', en: 'Apple Pay Error', ar: 'خطأ في Apple Pay', ur: 'ایپل پے کی خرابی' },
                { old: 'There was an error processing your Apple Pay payment.', key: 'errorProcessingApplePay', en: 'There was an error processing your Apple Pay payment.', ar: 'حدث خطأ أثناء معالجة دفع Apple Pay.', ur: 'آپ کے ایپل پے کی ادائیگی پر کارروائی کرنے میں ایک خرابی تھی۔' },
                { old: 'Use Another Payment Method', key: 'useAnotherPaymentMethod', en: 'Use Another Payment Method', ar: 'استخدم طريقة دفع أخرى', ur: 'ادائیگی کا دوسرا طریقہ استعمال کریں' },
            ]
        },
        {
            file: path.join(bkkPath, 'sheets', 'filter.dart'),
            items: [
                { old: 'Failed to load locations. Location filters may not be available.', key: 'failedLoadLocations', en: 'Failed to load locations. Location filters may not be available.', ar: 'فشل تحميل المواقع. قد لا تكون فلاتر الموقع متوفرة.', ur: 'مقامات لوڈ کرنے میں ناکام۔ مقام کے فلٹرز دستیاب نہیں ہوسکتے ہیں۔' },
                { old: 'Failed to load categories. Some filters may not be available.', key: 'failedLoadCategories', en: 'Failed to load categories. Some filters may not be available.', ar: 'فشل تحميل الفئات. قد لا تكون بعض الفلاتر متوفرة.', ur: 'زمرے لوڈ کرنے میں ناکام۔ کچھ فلٹرز دستیاب نہیں ہوسکتے ہیں۔' },
            ]
        }
    ],
    tech: [
        {
            file: path.join(techPath, 'pages', 'bookings', 'widgets', 'counter_propose_sheet.dart'),
            items: [
                { old: 'Select a new date and time for the appointment', key: 'selectNewDateAppointment', en: 'Select a new date and time for the appointment', ar: 'حدد تاريخًا ووقتًا جديدين للموعد', ur: 'ملاقات کے لیے نئی تاریخ اور وقت منتخب کریں' }
            ]
        }
    ]
};

function updateArb(arbPath, newEntries) {
    if (fs.existsSync(arbPath)) {
        const content = JSON.parse(fs.readFileSync(arbPath, 'utf8'));
        let changed = false;
        for (const [k, v] of Object.entries(newEntries)) {
            if (!content[k]) {
                content[k] = v;
                changed = true;
            }
        }
        if (changed) {
            fs.writeFileSync(arbPath, JSON.stringify(content, null, 2), 'utf8');
            console.log(Updated );
        }
    }
}

for (const app of ['bkk', 'tech']) {
    const enEntries = {};
    const arEntries = {};
    const urEntries = {};

    for (const r of replacements[app]) {
        for (const item of r.items) {
            enEntries[item.key] = item.en;
            arEntries[item.key] = item.ar;
            urEntries[item.key] = item.ur;
        }
    }

    updateArb(arbPaths[app].en, enEntries);
    updateArb(arbPaths[app].ar, arEntries);
    updateArb(arbPaths[app].ur, urEntries);

    for (const r of replacements[app]) {
        if (fs.existsSync(r.file)) {
            let content = fs.readFileSync(r.file, 'utf8');
            let changed = false;
            for (const item of r.items) {
                const searchStr = item.old;
                const replacementStr = (AppLocalizations.of(context)?. ?? );
                if (content.includes(searchStr)) {
                    content = content.replace(searchStr, replacementStr);
                    changed = true;
                }
            }
            if (changed) {
                fs.writeFileSync(r.file, content, 'utf8');
                console.log(Replaced strings in );
            }
        }
    }
}
