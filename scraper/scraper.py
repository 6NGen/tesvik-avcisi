# scraper/scraper.py
# Teşvik Avcısı - Otomatik Veri Toplama Botu (Gemini'siz versiyon)
# Resmi siteleri doğrudan HTML parser ile tarar.
# Gemini kullanmaz → kota sorunu yok, yanlış veri riski yok.

import os
import re
import time
import requests
from datetime import datetime, timedelta
from bs4 import BeautifulSoup
from supabase import create_client, Client

# ── YAPILANDIRMA ──────────────────────────────────────────────────

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "tr-TR,tr;q=0.9",
}

# ── KAYNAK TARAYICILAR ────────────────────────────────────────────

def tkdk_tara() -> list:
    """TKDK resmi duyuru sayfasını tarar."""
    tesvikler = []
    urls = [
        "https://www.tkdk.gov.tr/Hibe/Index",
        "https://www.tkdk.gov.tr/Duyuru/Index",
    ]
    for url in urls:
        try:
            r = requests.get(url, headers=HEADERS, timeout=15)
            soup = BeautifulSoup(r.text, "lxml")

            # Başlık ve linkleri çek
            for item in soup.find_all(["h2", "h3", "h4", "a"], limit=30):
                metin = item.get_text(strip=True)
                href = item.get("href", "")

                # Teşvik/hibe içeren başlıkları filtrele
                if any(k in metin.lower() for k in
                       ["hibe", "destek", "başvuru", "ipard", "çağrı"]):
                    if len(metin) > 15:
                        link = href if href.startswith("http") else f"https://www.tkdk.gov.tr{href}"
                        tesvikler.append({
                            "isim": metin[:200],
                            "kurum": "TKDK (IPARD)",
                            "basvuru_url": link or url,
                            "kaynak_url": url,
                            "son_basvuru_tarihi": _tarih_tahmin_et(metin),
                            "uygun_iller": [],
                            "uygun_urunler": _urun_cikar(metin),
                            "etiketler": _etiket_cikar(metin),
                        })
        except Exception as e:
            print(f"  ⚠️  TKDK hata: {e}")

    return tesvikler[:10]  # max 10 kayıt


def tarim_bakanligi_tara() -> list:
    """Tarım ve Orman Bakanlığı duyurularını tarar."""
    tesvikler = []
    urls = [
        "https://www.tarimorman.gov.tr/Haber/Index",
        "https://www.tarimorman.gov.tr/Duyuru/Index",
    ]
    for url in urls:
        try:
            r = requests.get(url, headers=HEADERS, timeout=15)
            soup = BeautifulSoup(r.text, "lxml")

            for item in soup.find_all(["h2", "h3", "h4", "a"], limit=30):
                metin = item.get_text(strip=True)
                href = item.get("href", "")

                if any(k in metin.lower() for k in
                       ["destek", "hibe", "ödeme", "başvuru", "prim"]):
                    if len(metin) > 15:
                        link = href if href.startswith("http") else f"https://www.tarimorman.gov.tr{href}"
                        tesvikler.append({
                            "isim": metin[:200],
                            "kurum": "Tarım ve Orman Bakanlığı",
                            "basvuru_url": link or url,
                            "kaynak_url": url,
                            "son_basvuru_tarihi": _tarih_tahmin_et(metin),
                            "uygun_iller": [],
                            "uygun_urunler": _urun_cikar(metin),
                            "etiketler": _etiket_cikar(metin),
                        })
        except Exception as e:
            print(f"  ⚠️  Bakanlık hata: {e}")

    return tesvikler[:10]


def kosgeb_tara() -> list:
    """KOSGEB destek programlarını tarar."""
    tesvikler = []
    url = "https://www.kosgeb.gov.tr/site/tr/genel/destekler"
    try:
        r = requests.get(url, headers=HEADERS, timeout=15)
        soup = BeautifulSoup(r.text, "lxml")

        for item in soup.find_all(["h2", "h3", "h4", "li", "a"], limit=40):
            metin = item.get_text(strip=True)
            href = item.get("href", "")

            if any(k in metin.lower() for k in
                   ["destek", "hibe", "tarım", "gıda", "kırsal"]):
                if len(metin) > 15:
                    link = href if href.startswith("http") else f"https://www.kosgeb.gov.tr{href}"
                    tesvikler.append({
                        "isim": metin[:200],
                        "kurum": "KOSGEB",
                        "basvuru_url": link or url,
                        "kaynak_url": url,
                        "son_basvuru_tarihi": None,
                        "uygun_iller": [],
                        "uygun_urunler": [],
                        "etiketler": ["KOBİ"] + _etiket_cikar(metin),
                    })
    except Exception as e:
        print(f"  ⚠️  KOSGEB hata: {e}")

    return tesvikler[:8]


def tubitak_tara() -> list:
    """TÜBİTAK tarımsal AR-GE desteklerini tarar."""
    tesvikler = []
    url = "https://www.tubitak.gov.tr/tr/destekler/akademik/ulusal-destek-programlari"
    try:
        r = requests.get(url, headers=HEADERS, timeout=15)
        soup = BeautifulSoup(r.text, "lxml")

        for item in soup.find_all(["h2", "h3", "a"], limit=30):
            metin = item.get_text(strip=True)
            href = item.get("href", "")

            if any(k in metin.lower() for k in
                   ["tarım", "gıda", "hayvancılık", "bitkisel"]):
                if len(metin) > 15:
                    link = href if href.startswith("http") else f"https://www.tubitak.gov.tr{href}"
                    tesvikler.append({
                        "isim": metin[:200],
                        "kurum": "TÜBİTAK",
                        "basvuru_url": link or url,
                        "kaynak_url": url,
                        "son_basvuru_tarihi": _tarih_tahmin_et(metin),
                        "uygun_iller": [],
                        "uygun_urunler": _urun_cikar(metin),
                        "etiketler": ["AR-GE"] + _etiket_cikar(metin),
                    })
    except Exception as e:
        print(f"  ⚠️  TÜBİTAK hata: {e}")

    return tesvikler[:5]


def kalkinma_ajanslari_tara() -> list:
    """Kalkınma ajansları hibe duyurularını tarar."""
    tesvikler = []
    urls = [
        "https://www.dogaka.gov.tr/hibe-destekleri",
        "https://www.oran.org.tr/destekler",
        "https://www.daka.org.tr/destekler",
    ]
    for url in urls:
        try:
            r = requests.get(url, headers=HEADERS, timeout=10)
            soup = BeautifulSoup(r.text, "lxml")

            for item in soup.find_all(["h2", "h3", "a"], limit=20):
                metin = item.get_text(strip=True)
                href = item.get("href", "")

                if any(k in metin.lower() for k in
                       ["hibe", "destek", "tarım", "kırsal"]):
                    if len(metin) > 15:
                        link = href if href.startswith("http") else url
                        tesvikler.append({
                            "isim": metin[:200],
                            "kurum": "Kalkınma Ajansı",
                            "basvuru_url": link,
                            "kaynak_url": url,
                            "son_basvuru_tarihi": _tarih_tahmin_et(metin),
                            "uygun_iller": [],
                            "uygun_urunler": [],
                            "etiketler": _etiket_cikar(metin),
                        })
        except Exception as e:
            print(f"  ⚠️  Kalkınma Ajansı hata ({url}): {e}")

    return tesvikler[:8]


# ── YARDIMCI FONKSİYONLAR ─────────────────────────────────────────

def _tarih_tahmin_et(metin: str):
    """Metinden tarih çıkarmaya çalışır."""
    # DD.MM.YYYY veya DD/MM/YYYY formatını ara
    pattern = r'\b(\d{1,2})[./](\d{1,2})[./](20\d{2})\b'
    eslesme = re.search(pattern, metin)
    if eslesme:
        try:
            gun, ay, yil = eslesme.groups()
            tarih = datetime(int(yil), int(ay), int(gun))
            # Geçmiş tarihse None döndür
            if tarih > datetime.now():
                return tarih.strftime("%Y-%m-%d")
        except:
            pass
    return None


def _urun_cikar(metin: str) -> list:
    """Metinden tarımsal ürün adlarını çıkarır."""
    urunler = []
    urun_listesi = [
        "buğday", "arpa", "mısır", "ayçiçeği", "pamuk",
        "domates", "biber", "patates", "soğan", "bal",
        "süt", "et", "zeytin", "fındık", "üzüm",
    ]
    metin_lower = metin.lower()
    for urun in urun_listesi:
        if urun in metin_lower:
            urunler.append(urun.capitalize())
    return urunler


def _etiket_cikar(metin: str) -> list:
    """Metinden etiketleri çıkarır."""
    etiketler = []
    metin_lower = metin.lower()
    if "genç" in metin_lower:
        etiketler.append("genç çiftçi")
    if "kadın" in metin_lower:
        etiketler.append("kadın çiftçi")
    if "organik" in metin_lower:
        etiketler.append("organik")
    if "sulama" in metin_lower:
        etiketler.append("sulama")
    if "makine" in metin_lower or "ekipman" in metin_lower:
        etiketler.append("makine")
    if "arıcılık" in metin_lower or "arı" in metin_lower:
        etiketler.append("arıcılık")
    if "hayvancılık" in metin_lower:
        etiketler.append("hayvancılık")
    return etiketler


# ── SUPABASE İŞLEMLERİ ────────────────────────────────────────────

def supabase_baglan() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def mevcut_tesvikleri_getir(db: Client) -> set:
    """Mevcut teşvik isimlerini set olarak döner."""
    try:
        response = db.table("tesvikler").select("isim").execute()
        return {r["isim"] for r in (response.data or [])}
    except:
        return set()


def tesvik_kaydet(db: Client, tesvik: dict, mevcutlar: set) -> str:
    """Teşviki Supabase'e ekler. Zaten varsa atlar."""
    isim = tesvik.get("isim", "").strip()
    if not isim or isim in mevcutlar:
        return "atlandi"

    kayit = {
        "isim": isim,
        "kurum": tesvik.get("kurum", ""),
        "basvuru_url": tesvik.get("basvuru_url"),
        "son_basvuru_tarihi": tesvik.get("son_basvuru_tarihi"),
        "uygun_iller": tesvik.get("uygun_iller", []),
        "uygun_urunler": tesvik.get("uygun_urunler", []),
        "etiketler": tesvik.get("etiketler", []),
        "aktif": True,
        "guncelleme": datetime.now().isoformat(),
    }

    try:
        db.table("tesvikler").insert(kayit).execute()
        return "eklendi"
    except Exception as e:
        print(f"  ⚠️  Kayıt hatası: {e}")
        return "hata"


def suresi_gecenleri_pasife_al(db: Client):
    """Son başvuru tarihi geçmiş teşvikleri pasife al."""
    bugun = datetime.now().strftime("%Y-%m-%d")
    try:
        db.table("tesvikler").update({"aktif": False}).lt(
            "son_basvuru_tarihi", bugun
        ).execute()
        print("🧹 Süresi geçen teşvikler pasife alındı.")
    except Exception as e:
        print(f"  ⚠️  Temizleme hatası: {e}")


# ── ANA FONKSİYON ─────────────────────────────────────────────────

def main():
    print("=" * 55)
    print(f"🌾 Teşvik Avcısı Bot - {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 55)

    db = supabase_baglan()
    mevcutlar = mevcut_tesvikleri_getir(db)
    print(f"📊 Mevcut teşvik sayısı: {len(mevcutlar)}\n")

    # Tüm tarayıcıları çalıştır
    kaynaklar = [
        ("TKDK (IPARD)",            tkdk_tara),
        ("Tarım Bakanlığı",         tarim_bakanligi_tara),
        ("KOSGEB",                  kosgeb_tara),
        ("TÜBİTAK",                 tubitak_tara),
        ("Kalkınma Ajansları",      kalkinma_ajanslari_tara),
    ]

    toplam_eklenen = 0

    for ad, tarayici in kaynaklar:
        print(f"🔍 Taranıyor: {ad}")
        tesvikler = tarayici()
        print(f"   {len(tesvikler)} kayıt bulundu")

        for t in tesvikler:
            sonuc = tesvik_kaydet(db, t, mevcutlar)
            if sonuc == "eklendi":
                toplam_eklenen += 1
                mevcutlar.add(t["isim"])
                print(f"   ➕ {t['isim'][:60]}")

        time.sleep(2)  # Sitelere saygılı ol
        print()

    suresi_gecenleri_pasife_al(db)

    print("=" * 55)
    print(f"✅ Tamamlandı! {toplam_eklenen} yeni teşvik eklendi.")
    print("=" * 55)


if __name__ == "__main__":
    main()