# scraper/scraper.py
# Teşvik Avcısı Bot v2 — Kaliteli Veri Odaklı
# Genel haber sayfaları değil, spesifik hibe/destek sayfalarını tarar.
# Gemini yok → kota sorunu yok.
# Her teşvik için: başlık + resmi link + tarih + etiket

import os
import re
import time
import requests
from datetime import datetime
from bs4 import BeautifulSoup
from supabase import create_client, Client

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "tr-TR,tr;q=0.9",
    "Accept": "text/html,application/xhtml+xml",
}

# ── HEDEF SAYFALAR ────────────────────────────────────────────────
# Genel haber değil, spesifik hibe/destek sayfaları

HEDEF_SAYFALAR = [
    {
        "kurum": "TKDK (IPARD)",
        "url": "https://www.tkdk.gov.tr/Hibe/Index",
        "baslik_selector": "h3, h4, .hibe-title, .card-title",
        "link_base": "https://www.tkdk.gov.tr",
        "etiketler": ["ipard", "hibe", "tarım"],
    },
    {
        "kurum": "TKDK (IPARD)",
        "url": "https://www.tkdk.gov.tr/Duyuru/Index",
        "baslik_selector": "h3, h4, .duyuru-title",
        "link_base": "https://www.tkdk.gov.tr",
        "etiketler": ["ipard", "duyuru"],
    },
    {
        "kurum": "Tarım ve Orman Bakanlığı",
        "url": "https://www.tarimorman.gov.tr/Haber/Index",
        "baslik_selector": "h3, h4, .haber-title, .news-title",
        "link_base": "https://www.tarimorman.gov.tr",
        "etiketler": ["tarım", "bakanlık"],
    },
    {
        "kurum": "Tarım ve Orman Bakanlığı",
        "url": "https://www.tarimorman.gov.tr/Duyuru/Index",
        "baslik_selector": "h3, h4, .duyuru-title",
        "link_base": "https://www.tarimorman.gov.tr",
        "etiketler": ["tarım", "duyuru"],
    },
    {
        "kurum": "KOSGEB",
        "url": "https://www.kosgeb.gov.tr/site/tr/genel/destekler",
        "baslik_selector": "h3, h4, .destek-title, .program-title",
        "link_base": "https://www.kosgeb.gov.tr",
        "etiketler": ["kosgeb", "KOBİ"],
    },
]

# Teşvikle ilgili anahtar kelimeler
HIBE_ANAHTAR = [
    "hibe", "destek", "ödeme", "başvuru", "teşvik",
    "ipard", "kkydp", "çağrı", "program", "proje",
    "yatırım", "finansman", "kredi",
]

# ── YARDIMCI FONKSİYONLAR ─────────────────────────────────────────

def sayfa_cek(url: str) -> BeautifulSoup | None:
    """URL'den BeautifulSoup nesnesi döndürür."""
    try:
        r = requests.get(url, headers=HEADERS, timeout=15)
        r.raise_for_status()
        r.encoding = "utf-8"
        return BeautifulSoup(r.text, "lxml")
    except Exception as e:
        print(f"  ⚠️  {url}: {e}")
        return None


def tarih_cek(metin: str) -> str | None:
    """
    Metinden Türkçe tarih çıkarır.
    Desteklenen formatlar:
    - 15.03.2026
    - 15/03/2026
    - 15 Mart 2026
    - Mart 2026
    """
    aylar = {
        "ocak": "01", "şubat": "02", "mart": "03",
        "nisan": "04", "mayıs": "05", "haziran": "06",
        "temmuz": "07", "ağustos": "08", "eylül": "09",
        "ekim": "10", "kasım": "11", "aralık": "12",
    }

    metin_lower = metin.lower()

    # DD.MM.YYYY veya DD/MM/YYYY
    m = re.search(r'\b(\d{1,2})[./](\d{1,2})[./](20\d{2})\b', metin)
    if m:
        try:
            gun, ay, yil = int(m.group(1)), int(m.group(2)), int(m.group(3))
            tarih = datetime(yil, ay, gun)
            if tarih > datetime.now():
                return tarih.strftime("%Y-%m-%d")
        except:
            pass

    # DD Ay YYYY
    for ay_ad, ay_no in aylar.items():
        m = re.search(rf'\b(\d{{1,2}})\s+{ay_ad}\s+(20\d{{2}})\b', metin_lower)
        if m:
            try:
                gun, yil = int(m.group(1)), int(m.group(2))
                tarih = datetime(yil, int(ay_no), gun)
                if tarih > datetime.now():
                    return tarih.strftime("%Y-%m-%d")
            except:
                pass

    # Ay YYYY (sadece ay ve yıl)
    for ay_ad, ay_no in aylar.items():
        m = re.search(rf'\b{ay_ad}\s+(20\d{{2}})\b', metin_lower)
        if m:
            try:
                yil = int(m.group(1))
                # Ayın son gününü kullan
                import calendar
                son_gun = calendar.monthrange(yil, int(ay_no))[1]
                tarih = datetime(yil, int(ay_no), son_gun)
                if tarih > datetime.now():
                    return tarih.strftime("%Y-%m-%d")
            except:
                pass

    return None


def hibe_mi(metin: str) -> bool:
    """Metnin teşvik/hibe içerip içermediğini kontrol eder."""
    metin_lower = metin.lower()
    return any(k in metin_lower for k in HIBE_ANAHTAR)


def urun_cikar(metin: str) -> list:
    """Metinden ürün adlarını çıkarır."""
    urunler = []
    urun_esleme = {
        "buğday": "Buğday", "arpa": "Arpa", "mısır": "Mısır",
        "ayçiçeği": "Ayçiçeği", "pamuk": "Pamuk",
        "domates": "Domates", "biber": "Biber", "patates": "Patates",
        "soğan": "Soğan", "şeker pancarı": "Şeker Pancarı",
        "zeytin": "Zeytin", "fındık": "Fındık", "çay": "Çay",
        "üzüm": "Üzüm", "kiraz": "Kiraz", "elma": "Elma",
        "bal": "Süzme Bal", "arıcılık": "Süzme Bal",
        "büyükbaş": "Büyükbaş (Süt)", "küçükbaş": "Küçükbaş (Koyun)",
        "süt": "Büyükbaş (Süt)",
    }
    metin_lower = metin.lower()
    for anahtar, urun in urun_esleme.items():
        if anahtar in metin_lower and urun not in urunler:
            urunler.append(urun)
    return urunler


def ek_etiket_cikar(metin: str) -> list:
    """Metinden ek etiketler çıkarır."""
    etiketler = []
    metin_lower = metin.lower()
    if "genç" in metin_lower: etiketler.append("genç çiftçi")
    if "kadın" in metin_lower: etiketler.append("kadın çiftçi")
    if "organik" in metin_lower: etiketler.append("organik")
    if "sulama" in metin_lower: etiketler.append("sulama")
    if "makine" in metin_lower or "ekipman" in metin_lower: etiketler.append("makine")
    if "arıcılık" in metin_lower or "kovan" in metin_lower: etiketler.append("arıcılık")
    if "hayvancılık" in metin_lower: etiketler.append("hayvancılık")
    if "depolama" in metin_lower: etiketler.append("depolama")
    if "sera" in metin_lower: etiketler.append("sera")
    return etiketler


# ── ANA TARAYICI ──────────────────────────────────────────────────

def sayfa_tara(hedef: dict) -> list:
    """Tek bir sayfayı tarar, teşvik listesi döndürür."""
    tesvikler = []
    soup = sayfa_cek(hedef["url"])
    if not soup:
        return []

    # Tüm link ve başlık elementlerini tara
    for element in soup.find_all(["a", "h2", "h3", "h4", "h5"], limit=50):
        metin = element.get_text(strip=True)
        if not metin or len(metin) < 20 or len(metin) > 300:
            continue

        if not hibe_mi(metin):
            continue

        # Link bul
        href = ""
        if element.name == "a":
            href = element.get("href", "")
        else:
            # Parent veya child link ara
            parent_a = element.find_parent("a")
            child_a = element.find("a")
            if parent_a:
                href = parent_a.get("href", "")
            elif child_a:
                href = child_a.get("href", "")

        # Linki tam URL'e çevir
        if href and not href.startswith("http"):
            href = hedef["link_base"] + href
        if not href:
            href = hedef["url"]

        # Tarih çıkar
        tarih = tarih_cek(metin)

        # Ürün ve etiket çıkar
        urunler = urun_cikar(metin)
        etiketler = list(set(hedef["etiketler"] + ek_etiket_cikar(metin)))

        tesvikler.append({
            "isim": metin[:250],
            "kurum": hedef["kurum"],
            "basvuru_url": href,
            "son_basvuru_tarihi": tarih,
            "uygun_iller": [],
            "uygun_urunler": urunler,
            "etiketler": etiketler,
        })

    return tesvikler


# ── SUPABASE ──────────────────────────────────────────────────────

def supabase_baglan() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def mevcut_isimler(db: Client) -> set:
    try:
        r = db.table("tesvikler").select("isim").execute()
        return {row["isim"] for row in (r.data or [])}
    except:
        return set()


def kaydet(db: Client, tesvik: dict, mevcutlar: set) -> bool:
    isim = tesvik["isim"].strip()

    # Çok kısa veya anlamsız başlıkları atla
    if len(isim) < 25:
        return False

    # Zaten varsa atla
    if isim in mevcutlar:
        return False

    # Blacklist — anlamsız başlıklar
    blacklist = [
        "tıklayın", "devamı", "daha fazla", "haberleri",
        "all rights", "copyright", "cookie",
    ]
    if any(b in isim.lower() for b in blacklist):
        return False

    try:
        db.table("tesvikler").insert({
            "isim": isim,
            "kurum": tesvik.get("kurum", ""),
            "basvuru_url": tesvik.get("basvuru_url"),
            "son_basvuru_tarihi": tesvik.get("son_basvuru_tarihi"),
            "uygun_iller": tesvik.get("uygun_iller", []),
            "uygun_urunler": tesvik.get("uygun_urunler", []),
            "etiketler": tesvik.get("etiketler", []),
            "aktif": True,
            "guncelleme": datetime.now().isoformat(),
        }).execute()
        return True
    except Exception as e:
        print(f"  ⚠️  Kayıt hatası: {e}")
        return False


def suresi_gecenleri_pasife_al(db: Client):
    bugun = datetime.now().strftime("%Y-%m-%d")
    try:
        db.table("tesvikler").update({"aktif": False}).lt(
            "son_basvuru_tarihi", bugun
        ).not_.is_("son_basvuru_tarihi", "null").execute()
        print("🧹 Süresi geçenler pasife alındı.")
    except Exception as e:
        print(f"  ⚠️  Temizleme: {e}")


# ── MAIN ──────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print(f"🌾 Teşvik Avcısı Bot v2 — {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 55)

    db = supabase_baglan()
    mevcutlar = mevcut_isimler(db)
    print(f"📊 Mevcut teşvik: {len(mevcutlar)}\n")

    toplam = 0

    for hedef in HEDEF_SAYFALAR:
        print(f"🔍 {hedef['kurum']} — {hedef['url']}")
        tesvikler = sayfa_tara(hedef)
        print(f"   {len(tesvikler)} aday bulundu")

        for t in tesvikler:
            if kaydet(db, t, mevcutlar):
                toplam += 1
                mevcutlar.add(t["isim"])
                print(f"   ➕ {t['isim'][:60]}")

        time.sleep(2)

    suresi_gecenleri_pasife_al(db)

    print("\n" + "=" * 55)
    print(f"✅ Tamamlandı! {toplam} yeni teşvik eklendi.")
    print("=" * 55)


if __name__ == "__main__":
    main()