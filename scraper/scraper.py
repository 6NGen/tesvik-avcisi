# scraper/scraper.py
# Teşvik Avcısı - Otomatik Veri Toplama Botu
# Her gece çalışır, 6 kaynaktan teşvik verisi çeker,
# Gemini ile parse eder, Supabase'e kaydeder.

import os
import json
import time
import requests
from datetime import datetime
from bs4 import BeautifulSoup
import google.generativeai as genai
from supabase import create_client, Client

# ── YAPILANDIRMA ──────────────────────────────────────────────────

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")  # service_role key (bot için)
GEMINI_KEY   = os.environ.get("GEMINI_API_KEY")

# Taranacak kaynaklar
KAYNAKLAR = [
    {
        "kurum": "TKDK (IPARD)",
        "url": "https://www.tkdk.gov.tr/Haber/Index",
        "yedek_url": "https://www.tkdk.gov.tr/Hibe/Index",
        "anahtar_kelimeler": ["hibe", "destek", "başvuru", "IPARD"],
    },
    {
        "kurum": "Tarım ve Orman Bakanlığı",
        "url": "https://www.tarimorman.gov.tr/Haber/Index",
        "yedek_url": "https://www.tarimorman.gov.tr/Duyuru/Index",
        "anahtar_kelimeler": ["destek", "hibe", "ödeme", "başvuru"],
    },
    {
        "kurum": "KKYDP",
        "url": "https://www.tarim.gov.tr/TRGM/Belgeler/KKYDP",
        "yedek_url": "https://www.tarimorman.gov.tr/TRGM/Haber/Index",
        "anahtar_kelimeler": ["KKYDP", "kırsal", "kalkınma", "destek"],
    },
    {
        "kurum": "TÜBİTAK",
        "url": "https://www.tubitak.gov.tr/tr/destekler/tarimsal-arastirma-destekleri",
        "yedek_url": "https://www.tubitak.gov.tr/tr/haber",
        "anahtar_kelimeler": ["tarım", "AR-GE", "proje", "destek"],
    },
    {
        "kurum": "KOSGEB",
        "url": "https://www.kosgeb.gov.tr/site/tr/genel/destekler",
        "yedek_url": "https://www.kosgeb.gov.tr/site/tr/genel/haberler",
        "anahtar_kelimeler": ["destek", "hibe", "KOBİ", "tarım", "gıda"],
    },
    {
        "kurum": "Kalkınma Ajansları",
        "url": "https://www.sbb.gov.tr/kalkinma-ajanslari/",
        "yedek_url": "https://www.dogaka.gov.tr/",
        "anahtar_kelimeler": ["hibe", "destek", "başvuru", "proje"],
    },
]

# ── GEMİNİ KURULUMU ───────────────────────────────────────────────

def gemini_baslat():
    genai.configure(api_key=GEMINI_KEY)
    return genai.GenerativeModel("gemini-2.0-flash")

# ── WEB SCRAPING ──────────────────────────────────────────────────

def sayfa_icerigini_cek(url: str) -> str:
    """Verilen URL'den metin içeriğini çeker."""
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
        ),
        "Accept-Language": "tr-TR,tr;q=0.9",
        "Accept": "text/html,application/xhtml+xml",
    }
    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")

        # Gereksiz elementleri kaldır
        for tag in soup(["script", "style", "nav", "footer", "header"]):
            tag.decompose()

        # Sadece ana içerik
        metin = soup.get_text(separator="\n", strip=True)

        # Max 4000 karakter (Gemini limiti için)
        return metin[:4000]

    except Exception as e:
        print(f"  ⚠️  Sayfa çekilemedi ({url}): {e}")
        return ""

# ── GEMİNİ PARSE ──────────────────────────────────────────────────

def gemini_ile_parse_et(model, kaynak: dict, icerik: str) -> list:
    """
    Gemini'ye ham HTML içeriğini gönderir,
    yapılandırılmış teşvik verisi olarak döndürür.
    """
    if not icerik.strip():
        return []

    bugun = datetime.now().strftime("%Y-%m-%d")

    prompt = f"""
Bugünün tarihi: {bugun}
Kaynak kurum: {kaynak['kurum']}
Kaynak URL: {kaynak['url']}

Aşağıdaki web sayfası içeriğinden aktif tarımsal teşvik, hibe ve destekleri çıkar.
Sadece GERÇEK ve GÜNCEL destekleri listele. Geçmiş tarihlileri dahil etme.

Her teşvik için şu JSON formatını kullan:
{{
  "tesvikler": [
    {{
      "isim": "Teşvikin tam adı",
      "kurum": "{kaynak['kurum']}",
      "aciklama": "Kısa açıklama (max 200 karakter)",
      "basvuru_url": "Başvuru linki veya ana sayfa URL'si",
      "son_basvuru_tarihi": "YYYY-MM-DD formatında veya null",
      "hibe_orani": "Yüzde olarak sayı veya null (örn: 50)",
      "uygun_iller": [],
      "uygun_urunler": ["Buğday", "Arpa"] veya [],
      "min_dekar": null veya sayı,
      "etiketler": ["genç çiftçi", "organik"] veya []
    }}
  ]
}}

Teşvik bulunamazsa: {{"tesvikler": []}}
SADECE JSON döndür, başka hiçbir şey yazma.

İÇERİK:
{icerik}
"""

    try:
        response = model.generate_content(prompt)
        metin = response.text.strip()

        # JSON temizle
        metin = metin.replace("```json", "").replace("```", "").strip()

        veri = json.loads(metin)
        return veri.get("tesvikler", [])

    except json.JSONDecodeError as e:
        print(f"  ⚠️  JSON parse hatası: {e}")
        return []
    except Exception as e:
        print(f"  ⚠️  Gemini hatası: {e}")
        return []

# ── SUPABASE İŞLEMLERİ ────────────────────────────────────────────

def supabase_baglan() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def mevcut_tesvikleri_getir(db: Client) -> dict:
    """Mevcut teşvikleri isim+kurum bazında sözlük olarak döner."""
    response = db.table("tesvikler").select("id, isim, kurum").execute()
    return {
        f"{r['isim']}_{r['kurum']}": r['id']
        for r in (response.data or [])
    }

def tesvik_kaydet(db: Client, tesvik: dict, mevcut: dict) -> str:
    """
    Teşviki Supabase'e ekler veya günceller.
    Döner: 'eklendi' | 'guncellendi' | 'atlandi'
    """
    anahtar = f"{tesvik['isim']}_{tesvik['kurum']}"

    kayit = {
        "isim": tesvik.get("isim", ""),
        "kurum": tesvik.get("kurum", ""),
        "aciklama": tesvik.get("aciklama"),
        "basvuru_url": tesvik.get("basvuru_url"),
        "son_basvuru_tarihi": tesvik.get("son_basvuru_tarihi"),
        "hibe_orani": tesvik.get("hibe_orani"),
        "uygun_iller": tesvik.get("uygun_iller", []),
        "uygun_urunler": tesvik.get("uygun_urunler", []),
        "min_dekar": tesvik.get("min_dekar"),
        "etiketler": tesvik.get("etiketler", []),
        "guncelleme": datetime.now().isoformat(),
    }

    try:
        if anahtar in mevcut:
            # Güncelle
            db.table("tesvikler").update(kayit).eq(
                "id", mevcut[anahtar]
            ).execute()
            return "guncellendi"
        else:
            # Yeni ekle
            db.table("tesvikler").insert(kayit).execute()
            return "eklendi"
    except Exception as e:
        print(f"  ⚠️  Kayıt hatası ({tesvik.get('isim')}): {e}")
        return "atlandi"

def suresi_gecenleri_temizle(db: Client):
    """Son başvuru tarihi geçmiş teşvikleri pasife al."""
    bugun = datetime.now().strftime("%Y-%m-%d")
    try:
        db.table("tesvikler").update({"aktif": False}).lt(
            "son_basvuru_tarihi", bugun
        ).eq("aktif", True).execute()
        print("🧹 Süresi geçen teşvikler pasife alındı.")
    except Exception as e:
        print(f"⚠️  Temizleme hatası: {e}")

# ── ANA DÖNGÜ ─────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print(f"🌾 Teşvik Avcısı Bot - {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 60)

    # Bağlantılar
    model = gemini_baslat()
    db = supabase_baglan()
    mevcut = mevcut_tesvikleri_getir(db)

    print(f"📊 Mevcut teşvik sayısı: {len(mevcut)}\n")

    toplam_eklenen   = 0
    toplam_guncellen = 0
    toplam_hata      = 0

    for kaynak in KAYNAKLAR:
        print(f"🔍 Taranıyor: {kaynak['kurum']}")
        print(f"   URL: {kaynak['url']}")

        # Sayfayı çek
        icerik = sayfa_icerigini_cek(kaynak["url"])

        # Başarısız olursa yedek URL dene
        if not icerik and kaynak.get("yedek_url"):
            print(f"   Yedek URL deneniyor: {kaynak['yedek_url']}")
            icerik = sayfa_icerigini_cek(kaynak["yedek_url"])

        if not icerik:
            print(f"   ❌ İçerik alınamadı, atlanıyor.\n")
            toplam_hata += 1
            continue

        # Gemini ile parse et
        tesvikler = gemini_ile_parse_et(model, kaynak, icerik)
        print(f"   ✅ {len(tesvikler)} teşvik bulundu")

        # Supabase'e kaydet
        for t in tesvikler:
            sonuc = tesvik_kaydet(db, t, mevcut)
            if sonuc == "eklendi":
                toplam_eklenen += 1
                print(f"   ➕ Eklendi: {t.get('isim', '')[:50]}")
            elif sonuc == "guncellendi":
                toplam_guncellen += 1

        # Rate limit için bekle
        time.sleep(3)
        print()

    # Süresi geçenleri temizle
    suresi_gecenleri_temizle(db)

    # Özet
    print("=" * 60)
    print(f"✅ Tamamlandı!")
    print(f"   ➕ Yeni eklenen : {toplam_eklenen}")
    print(f"   🔄 Güncellenen  : {toplam_guncellen}")
    print(f"   ❌ Hatalı kaynak: {toplam_hata}")
    print("=" * 60)

if __name__ == "__main__":
    main()