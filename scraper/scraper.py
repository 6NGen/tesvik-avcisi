# scraper/scraper.py
# Teşvik Avcısı Bot v3 — Sitemap Tabanlı
# Tarım Bakanlığı ve TKDK sitemap'lerini tarar.
# Bot engeli yok, kota yok, Gemini yok.

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
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# ── HIBE/DESTEK ANAHTAR KELİMELERİ ──────────────────────────────

# URL'de bulunursa o sayfa taranır
URL_ANAHTAR = [
    "destek", "hibe", "odeme", "ödeme", "tarim-destekleri",
    "kkydp", "ipard", "kirsal", "kırsal", "hayvancilik",
    "hayvancılık", "aricil", "arıcıl", "organik", "sulama",
    "genç-çiftçi", "genc-ciftci", "mazot", "gubre", "gübre",
]

# Sayfa içeriğinde bulunursa teşvik olarak işlenir
ICERIK_ANAHTAR = [
    "hibe", "destek", "başvuru", "ödeme", "teşvik",
    "çağrı", "program", "proje", "yatırım", "finansman",
]

# Kara liste — anlamsız sayfalar
KARA_LISTE_URL = [
    "haber", "basin", "basın", "galeri", "foto", "video",
    "iletisim", "iletişim", "hakkimizda", "hakkında",
    "personel", "ihale", "kariyer",
]

# ── SİTEMAP TARAYICI ─────────────────────────────────────────────

def sitemap_url_cek(sitemap_url: str) -> list:
    """Sitemap'ten URL listesi çeker. İç içe sitemap'leri de destekler."""
    urls = []
    try:
        r = requests.get(sitemap_url, headers=HEADERS, timeout=20)
        r.raise_for_status()
        soup = BeautifulSoup(r.content, "xml")

        # İç içe sitemap index
        for sitemap in soup.find_all("sitemap"):
            loc = sitemap.find("loc")
            if loc:
                alt_urls = sitemap_url_cek(loc.text.strip())
                urls.extend(alt_urls)
                time.sleep(1)

        # Normal URL'ler
        for url_tag in soup.find_all("url"):
            loc = url_tag.find("loc")
            if loc:
                urls.append(loc.text.strip())

    except Exception as e:
        print(f"  ⚠️  Sitemap hatası ({sitemap_url}): {e}")

    return urls


def hibe_url_mu(url: str) -> bool:
    """URL'nin hibe/destek içerip içermediğini kontrol eder."""
    url_lower = url.lower()

    # Kara listedeyse atla
    if any(k in url_lower for k in KARA_LISTE_URL):
        return False

    # Anahtar kelime içeriyorsa al
    return any(k in url_lower for k in URL_ANAHTAR)


def sayfa_tara(url: str, kurum: str) -> dict | None:
    """Tek bir sayfayı tarar, teşvik verisi döndürür."""
    try:
        r = requests.get(url, headers=HEADERS, timeout=15)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "lxml")

        # Başlık çek
        baslik = None
        for tag in ["h1", "h2", "title"]:
            el = soup.find(tag)
            if el:
                baslik = el.get_text(strip=True)
                break

        if not baslik or len(baslik) < 10:
            return None

        # Sayfa içeriği hibe/destek içeriyor mu?
        sayfa_metni = soup.get_text(separator=" ", strip=True).lower()
        if not any(k in sayfa_metni for k in ICERIK_ANAHTAR):
            return None

        # Tarih çek
        tarih = _tarih_cek(sayfa_metni)

        # Ürün çek
        urunler = _urun_cikar(sayfa_metni)

        # Etiket çek
        etiketler = _etiket_cikar(sayfa_metni, url)

        return {
            "isim": baslik[:250],
            "kurum": kurum,
            "basvuru_url": url,
            "son_basvuru_tarihi": tarih,
            "uygun_iller": [],
            "uygun_urunler": urunler,
            "etiketler": etiketler,
        }

    except Exception as e:
        return None


# ── YARDIMCI FONKSİYONLAR ─────────────────────────────────────────

def _tarih_cek(metin: str) -> str | None:
    """Metinden gelecek tarih çıkarır."""
    aylar = {
        "ocak": "01", "şubat": "02", "mart": "03",
        "nisan": "04", "mayıs": "05", "haziran": "06",
        "temmuz": "07", "ağustos": "08", "eylül": "09",
        "ekim": "10", "kasım": "11", "aralık": "12",
    }

    # DD.MM.YYYY
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
        m = re.search(rf'\b(\d{{1,2}})\s+{ay_ad}\s+(20\d{{2}})\b', metin)
        if m:
            try:
                gun, yil = int(m.group(1)), int(m.group(2))
                tarih = datetime(yil, int(ay_no), gun)
                if tarih > datetime.now():
                    return tarih.strftime("%Y-%m-%d")
            except:
                pass

    # Ay YYYY
    import calendar
    for ay_ad, ay_no in aylar.items():
        m = re.search(rf'\b{ay_ad}\s+(20\d{{2}})\b', metin)
        if m:
            try:
                yil = int(m.group(1))
                son_gun = calendar.monthrange(yil, int(ay_no))[1]
                tarih = datetime(yil, int(ay_no), son_gun)
                if tarih > datetime.now():
                    return tarih.strftime("%Y-%m-%d")
            except:
                pass

    return None


def _urun_cikar(metin: str) -> list:
    urunler = []
    esleme = {
        "buğday": "Buğday", "arpa": "Arpa", "mısır": "Mısır",
        "ayçiçeği": "Ayçiçeği", "pamuk": "Pamuk",
        "domates": "Domates", "biber": "Biber", "patates": "Patates",
        "soğan": "Soğan", "şeker pancarı": "Şeker Pancarı",
        "zeytin": "Zeytin", "fındık": "Fındık", "çay": "Çay",
        "üzüm": "Üzüm", "kiraz": "Kiraz", "elma": "Elma",
        "bal": "Süzme Bal", "arıcılık": "Süzme Bal",
        "büyükbaş": "Büyükbaş (Süt)", "küçükbaş": "Küçükbaş (Koyun)",
        "süt üretim": "Büyükbaş (Süt)",
    }
    for anahtar, urun in esleme.items():
        if anahtar in metin and urun not in urunler:
            urunler.append(urun)
    return urunler[:6]


def _etiket_cikar(metin: str, url: str) -> list:
    etiketler = []
    if "genç" in metin or "genc" in url: etiketler.append("genç çiftçi")
    if "kadın" in metin: etiketler.append("kadın çiftçi")
    if "organik" in metin or "organik" in url: etiketler.append("organik")
    if "sulama" in metin or "sulama" in url: etiketler.append("sulama")
    if "makine" in metin or "ekipman" in metin: etiketler.append("makine")
    if "arıcılık" in metin or "arici" in url: etiketler.append("arıcılık")
    if "hayvancılık" in metin or "hayvan" in url: etiketler.append("hayvancılık")
    if "kkydp" in metin or "kkydp" in url: etiketler.append("kkydp")
    if "ipard" in metin or "ipard" in url: etiketler.append("ipard")
    if "mazot" in metin or "gübre" in metin: etiketler.append("mazot-gübre")
    if "kırsal" in metin or "kirsal" in url: etiketler.append("kırsal kalkınma")
    return etiketler


# ── SUPABASE ──────────────────────────────────────────────────────

def supabase_baglan() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def mevcut_urller(db: Client) -> set:
    try:
        r = db.table("tesvikler").select("basvuru_url").execute()
        return {row["basvuru_url"] for row in (r.data or []) if row.get("basvuru_url")}
    except:
        return set()


def kaydet(db: Client, tesvik: dict, mevcut: set) -> bool:
    url = tesvik.get("basvuru_url", "")
    isim = tesvik.get("isim", "").strip()

    if not isim or len(isim) < 15:
        return False
    if url in mevcut:
        return False

    try:
        db.table("tesvikler").insert({
            "isim": isim,
            "kurum": tesvik.get("kurum", ""),
            "basvuru_url": url,
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
        db.table("tesvikler").update({"aktif": False})\
            .lt("son_basvuru_tarihi", bugun)\
            .not_.is_("son_basvuru_tarihi", "null")\
            .execute()
        print("🧹 Süresi geçenler pasife alındı.")
    except Exception as e:
        print(f"  ⚠️  Temizleme: {e}")


# ── KAYNAKLAR ─────────────────────────────────────────────────────

KAYNAKLAR = [
    {
        "kurum": "Tarım ve Orman Bakanlığı",
        "sitemap": "https://tarim.gov.tr:443/sitemap.xml",
        "max_sayfa": 50,
    },
    {
        "kurum": "TKDK (IPARD)",
        "sitemap": None,  # Sitemap yok, doğrudan sayfalar
        "sayfalar": [
            "https://www.tkdk.gov.tr/Hibe/Index",
            "https://www.tkdk.gov.tr/Program/Index",
            "https://www.tkdk.gov.tr/Duyuru/Index",
        ],
        "max_sayfa": 10,
    },
    {
        "kurum": "KOSGEB",
        "sitemap": None,
        "sayfalar": [
            "https://www.kosgeb.gov.tr/site/tr/genel/destekler",
        ],
        "max_sayfa": 20,
    },
]


# ── MAIN ──────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print(f"🌾 Teşvik Avcısı Bot v3 — {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 55)

    db = supabase_baglan()
    mevcut = mevcut_urller(db)
    print(f"📊 Mevcut teşvik: {len(mevcut)}\n")

    toplam = 0

    for kaynak in KAYNAKLAR:
        kurum = kaynak["kurum"]
        print(f"\n🏛️  {kurum}")

        # Sitemap varsa sitemap'ten URL çek
        if kaynak.get("sitemap"):
            print(f"   📄 Sitemap taranıyor...")
            tum_urller = sitemap_url_cek(kaynak["sitemap"])
            print(f"   {len(tum_urller)} URL bulundu")

            # Hibe/destek URL'lerini filtrele
            hibe_urller = [u for u in tum_urller if hibe_url_mu(u)]
            print(f"   {len(hibe_urller)} hibe/destek URL'si seçildi")

            # Max sayfa sınırı
            hibe_urller = hibe_urller[:kaynak.get("max_sayfa", 30)]

        else:
            hibe_urller = kaynak.get("sayfalar", [])

        # Her URL'yi tara
        for url in hibe_urller:
            if url in mevcut:
                continue

            tesvik = sayfa_tara(url, kurum)
            if tesvik and kaydet(db, tesvik, mevcut):
                toplam += 1
                mevcut.add(url)
                print(f"   ➕ {tesvik['isim'][:60]}")

            time.sleep(1)  # Siteye saygılı ol

    suresi_gecenleri_pasife_al(db)

    print("\n" + "=" * 55)
    print(f"✅ Tamamlandı! {toplam} yeni teşvik eklendi.")
    print("=" * 55)


if __name__ == "__main__":
    main()