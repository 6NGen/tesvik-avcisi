# scraper/tkdk_pdf_parser.py
# TKDK çağrı takvimi PDF'ini okuyup Supabase'e kaydeder.
# Kullanım: scraper/ klasörüne tkdk_takvim.pdf ekle → bot otomatik işler.

import glob
import os
import json
import requests
from datetime import datetime
from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

pdf_dosyalari = glob.glob("scraper/*.pdf")
if not pdf_dosyalari:
    print("⏭️  scraper/ klasöründe PDF bulunamadı, atlanıyor.")
    exit(0)
PDF_YOLU = pdf_dosyalari[0]

PROMPT = """
Bu PDF bir TKDK (Tarım ve Kırsal Kalkınmayı Destekleme Kurumu) çağrı takvimi belgesidir.

Belgeden şu bilgileri çıkar ve SADECE JSON formatında döndür, başka hiçbir şey yazma:

{
  "tesvikler": [
    {
      "isim": "IPARD III M1 — ...",
      "kurum": "TKDK (IPARD)",
      "basvuru_tarihi_bitis": "YYYY-MM-DD",
      "cagri_ilani_tarihi": "YYYY-MM-DD",
      "butce_avro": 30000000,
      "kapsam": "Kısa açıklama",
      "etiketler": ["ipard", "tarım"]
    }
  ]
}

Kurallar:
- Sadece tarımsal destekleri al (M1, M3, M7 gibi tedbirler)
- Tarihleri YYYY-MM-DD formatına çevir (Nisan 2026 → 2026-04-30)
- Ay ismi varsa o ayın son günü olarak al
- TC Kimlik No, ad-soyad gibi kişisel verileri ASLA alma
- JSON dışında hiçbir şey yazma
"""


def gemini_ile_pdf_oku(pdf_bytes: bytes) -> list:
    """Gemini API ile PDF'i okur, teşvik listesi döndürür."""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"

    import base64
    pdf_b64 = base64.b64encode(pdf_bytes).decode("utf-8")

    payload = {
        "contents": [{
            "parts": [
                {"text": PROMPT},
                {
                    "inline_data": {
                        "mime_type": "application/pdf",
                        "data": pdf_b64
                    }
                }
            ]
        }]
    }

    response = requests.post(url, json=payload, timeout=60)
    response.raise_for_status()

    data = response.json()
    metin = data["candidates"][0]["content"]["parts"][0]["text"]

    # JSON temizle
    metin = metin.strip()
    if metin.startswith("```"):
        metin = metin.split("```")[1]
        if metin.startswith("json"):
            metin = metin[4:]
    metin = metin.strip()

    sonuc = json.loads(metin)
    return sonuc.get("tesvikler", [])


def supabase_guncelle(db, tesvikler: list):
    """Çekilen teşvikleri Supabase'e ekler veya günceller."""
    eklenen = 0
    guncellenen = 0

    for t in tesvikler:
        isim = t.get("isim", "").strip()
        if not isim or len(isim) < 10:
            continue

        # Mevcut kayıt var mı?
        mevcut = db.table("tesvikler")\
            .select("id")\
            .ilike("isim", f"%{isim[:30]}%")\
            .execute()

        kayit = {
            "isim": isim,
            "kurum": t.get("kurum", "TKDK (IPARD)"),
            "basvuru_url": "https://www.tkdk.gov.tr/Hibe/Index",
            "son_basvuru_tarihi": t.get("basvuru_tarihi_bitis"),
            "etiketler": t.get("etiketler", ["ipard"]),
            "uygun_iller": [],
            "uygun_urunler": [],
            "aktif": True,
            "guncelleme": datetime.now().isoformat(),
        }

        if mevcut.data:
            # Güncelle
            db.table("tesvikler")\
                .update(kayit)\
                .eq("id", mevcut.data[0]["id"])\
                .execute()
            guncellenen += 1
            print(f"  🔄 Güncellendi: {isim[:50]}")
        else:
            # Ekle
            db.table("tesvikler").insert(kayit).execute()
            eklenen += 1
            print(f"  ➕ Eklendi: {isim[:50]}")

    return eklenen, guncellenen


def main():
    print("=" * 55)
    print(f"📄 TKDK PDF Parser — {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 55)

    # PDF dosyası var mı?
    if not os.path.exists(PDF_YOLU):
        print(f"⏭️  {PDF_YOLU} bulunamadı, atlanıyor.")
        return

    print(f"📂 PDF okunuyor: {PDF_YOLU}")

    with open(PDF_YOLU, "rb") as f:
        pdf_bytes = f.read()

    print("🤖 Gemini ile analiz ediliyor...")

    try:
        tesvikler = gemini_ile_pdf_oku(pdf_bytes)
        print(f"✅ {len(tesvikler)} teşvik çıkarıldı")
    except Exception as e:
        print(f"⚠️  Gemini hatası: {e}")
        return

    db = create_client(SUPABASE_URL, SUPABASE_KEY)
    eklenen, guncellenen = supabase_guncelle(db, tesvikler)

    print(f"\n✅ Tamamlandı! {eklenen} eklendi, {guncellenen} güncellendi.")
    print("=" * 55)


if __name__ == "__main__":
    main()