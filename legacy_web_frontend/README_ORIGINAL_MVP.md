# SOFYAN YT — MVP (لم يُختبر بعد)

## المتطلبات (ويندوز 10)
- Python 3.12 (وليس 3.14: بعض المكتبات قد لا توفر إصدارات جاهزة له)
- Node.js 20+
- Tesseract OCR (نسخة UB Mannheim) مع حزم اللغات: ara, fra, eng

## تشغيل الخادم
    cd backend
    py -3.12 -m venv .venv
    .venv\Scripts\activate
    pip install -r requirements.txt
    copy .env.example .env      (ثم ضع المفتاح ومسار Tesseract)
    uvicorn main:app --reload --port 8000

## تشغيل الواجهة (نافذة ثانية)
    cd frontend
    npm install
    npm run dev      ← http://localhost:5173

## ملاحظات
- تصدير PDF يتم عبر طباعة المتصفح («حفظ كـ PDF»)، ويحافظ على RTL والعربية.
- مفتاح API يبقى في الخادم فقط.
