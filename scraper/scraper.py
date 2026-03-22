# scraper/scraper.py
# Teşvik Avcısı Bot v4 — yatirimadestek.gov.tr + KOSGEB
# Her gece 02:00 TR (UTC 23:00) çalışır.

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

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


# ── SUPABASE ──────────────────────────────────────────────────────

def supabase_baglan() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def mevcut_isimler(db: Client) -> set:
    """Supabase'deki mevcut teşvik isimlerini döndürür."""
    try:
        r = db.table("tesvikler").select("isim").execute()
        return {row["isim"].strip() for row in (r.data or []) if row.get("isim")}
    except:
        return set()


def kaydet(db: Client, tesvik: dict, mevcut: set) -> bool:
    """Teşviki Supabase'e ekler, zaten varsa atlar."""
    isim = tesvik.get("isim", "").strip()
    if not isim or len(isim) < 10:
        return False
    if isim in mevcut:
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
        print(f"  ⚠️  Kayıt hatası ({isim[:40]}): {e}")
        return False


def guncelle(db: Client, tesvik: dict) -> bool:
    """Mevcut teşvikin tarih ve aktiflik bilgisini günceller."""
    isim = tesvik.get("isim", "").strip()
    try:
        db.table("tesvikler").update({
            "son_basvuru_tarihi": tesvik.get("son_basvuru_tarihi"),
            "aktif": True,
            "guncelleme": datetime.now().isoformat(),
        }).eq("isim", isim).execute()
        return True
    except:
        return False


def suresi_gecenleri_pasife_al(db: Client):
    """Son başvuru tarihi geçmiş teşvikleri pasife alır."""
    bugun = datetime.now().strftime("%Y-%m-%d")
    try:
        db.table("tesvikler").update({"aktif": False})\
            .lt("son_basvuru_tarihi", bugun)\
            .not_.is_("son_basvuru_tarihi", "null")\
            .execute()
        print("🧹 Süresi geçenler pasife alındı.")
    except Exception as e:
        print(f"  ⚠️  Temizleme hatası: {e}")


# ── TARİH PARSER ─────────────────────────────────────────────────

def tarih_parse(metin: str) -> str | None:
    """
    'Sürekli Aktif', '31.12.2026', '05.09.2027' gibi
    metinleri YYYY-MM-DD formatına çevirir.
    """
    if not metin or "sürekli" in metin.lower():
        return None

    # DD.MM.YYYY
    m = re.search(r'(\d{1,2})\.(\d{1,2})\.(20\d{2})', metin)
    if m:
        try:
            gun, ay, yil = int(m.group(1)), int(m.group(2)), int(m.group(3))
            return datetime(yil, ay, gun).strftime("%Y-%m-%d")
        except:
            pass
    return None


# ── ÜRÜN / ETİKET EŞLEŞTİRME ─────────────────────────────────────

URUN_ESLEME = {
    "hayvancılık": ["Büyükbaş (Süt)", "Büyükbaş (Et)", "Küçükbaş (Koyun)", "Küçükbaş (Keçi)"],
    "büyükbaş": ["Büyükbaş (Süt)", "Büyükbaş (Et)"],
    "küçükbaş": ["Küçükbaş (Koyun)", "Küçükbaş (Keçi)"],
    "besiçilik": ["Büyükbaş (Et)"],
    "arıcılık": ["Süzme Bal", "Petek Bal", "Ana Arı", "Polen", "Propolis", "Arı Sütü"],
    "bal": ["Süzme Bal", "Petek Bal"],
    "organik": ["Organik Tahıl", "Organik Sebze", "Organik Meyve", "Organik Bal", "Organik Süt Ürünleri"],
    "fındık": ["Fındık"],
    "zeytin": ["Zeytin"],
    "tohum": ["Buğday", "Arpa", "Mısır", "Ayçiçeği"],
    "mazot": ["Buğday", "Arpa", "Mısır", "Ayçiçeği", "Pamuk", "Domates", "Patates", "Zeytin", "Fındık"],
    "gübre": ["Buğday", "Arpa", "Mısır", "Ayçiçeği", "Pamuk", "Domates", "Patates", "Zeytin", "Fındık"],
    "su ürünleri": ["Su Ürünleri"],
    "tarım havzaları": ["Buğday", "Arpa", "Mısır", "Ayçiçeği", "Pamuk", "Domates"],
    "gıda": ["Organik Tahıl", "Organik Sebze", "Organik Meyve"],
}

ETIKET_ESLEME = {
    "hayvancılık": "hayvancılık",
    "büyükbaş": "hayvancılık",
    "küçükbaş": "hayvancılık",
    "besiçilik": "hayvancılık",
    "arıcılık": "arıcılık",
    "organik": "organik",
    "fındık": "bitkisel",
    "zeytin": "bitkisel",
    "tohum": "bitkisel",
    "mazot": "mazot-gübre",
    "gübre": "mazot-gübre",
    "su ürünleri": "su ürünleri",
    "kredi": "kredi",
    "sigorta": "sigorta",
    "ağaçlandırma": "ağaçlandırma",
    "kira": "depolama",
    "çatak": "çevre",
    "kobi": "KOBİ",
    "gıda": "gıda",
}


def urun_ve_etiket_cikar(isim: str) -> tuple[list, list]:
    """Teşvik isminden ürün ve etiket listesi çıkarır."""
    isim_lower = isim.lower()
    urunler = []
    etiketler = ["tarım"]

    for anahtar, urun_listesi in URUN_ESLEME.items():
        if anahtar in isim_lower:
            for u in urun_listesi:
                if u not in urunler:
                    urunler.append(u)

    for anahtar, etiket in ETIKET_ESLEME.items():
        if anahtar in isim_lower and etiket not in etiketler:
            etiketler.append(etiket)

    return urunler[:8], etiketler


# ── YATIRIMADEStek.GOV.TR PARSER ─────────────────────────────────

def yatirimadestek_tara(db: Client, mevcut: set) -> int:
    """
    yatirimadestek.gov.tr'den Tarım Bakanlığı desteklerini çeker.
    Düz HTML, JavaScript yok — requests ile düzgün çalışır.
    """
    url = (
        "https://www.yatirimadestek.gov.tr/gelismis-arama"
        "?ajans_id=TARIM+VE+ORMAN+BAKANLI%C4%9EI&il_id=0&status=1"
    )
    print(f"\n🏛️  Tarım ve Orman Bakanlığı (yatirimadestek.gov.tr)")

    try:
        r = requests.get(url, headers=HEADERS, timeout=20, verify=False)
        r.raise_for_status()
    except Exception as e:
        print(f"  ⚠️  Bağlantı hatası: {e}")
        return 0

    soup = BeautifulSoup(r.text, "lxml")
    eklenen = 0

    # Her destek kartını bul
    # Sayfada "TARIM VE ORMAN BAKANLIĞI" başlıklı kartlar var
    kartlar = soup.find_all("div", class_=lambda c: c and "col" in c)

    # Alternatif: tüm metni satır satır parse et
    # Sayfa yapısı: isim, aktiflik, son başvuru tarihi sırayla geliyor
    metin_bloklari = []
    for tag in soup.find_all(["h5", "h4", "h3", "a", "span", "div"]):
        metin = tag.get_text(strip=True)
        if len(metin) > 15 and "TARIM VE ORMAN" not in metin and "AKTİF" not in metin:
            if any(k in metin.lower() for k in [
                "destek", "kredi", "hibe", "tarım", "hayvan",
                "arıcılık", "organik", "fındık", "zeytin", "gübre",
                "mazot", "sigorta", "ağaçlandırma", "besiçilik"
            ]):
                metin_bloklari.append(metin)

    # Son başvuru tarihlerini ayrı çek
    tarih_pattern = re.compile(r'Son Başvuru Tarihi\s*:\s*([^\n]+)', re.IGNORECASE)
    tum_metin = soup.get_text(separator="\n")
    tarihler = tarih_pattern.findall(tum_metin)
    tarih_iter = iter(tarihler)

    # İsim + tarih eşleştir
    islenen = set()
    for isim in metin_bloklari:
        isim = isim.strip()[:250]
        if isim in islenen or len(isim) < 15:
            continue
        islenen.add(isim)

        # Sıradaki tarihi al
        try:
            tarih_metin = next(tarih_iter).strip()
        except StopIteration:
            tarih_metin = ""

        son_tarih = tarih_parse(tarih_metin)
        urunler, etiketler = urun_ve_etiket_cikar(isim)

        tesvik = {
            "isim": isim,
            "kurum": "Tarım ve Orman Bakanlığı",
            "basvuru_url": "https://www.yatirimadestek.gov.tr/gelismis-arama?ajans_id=TARIM+VE+ORMAN+BAKANLI%C4%9EI&il_id=0&status=1",
            "son_basvuru_tarihi": son_tarih,
            "uygun_iller": [],
            "uygun_urunler": urunler,
            "etiketler": etiketler,
        }

        if isim in mevcut:
            guncelle(db, tesvik)
            print(f"  🔄 Güncellendi: {isim[:60]}")
        elif kaydet(db, tesvik, mevcut):
            eklenen += 1
            mevcut.add(isim)
            print(f"  ➕ Eklendi: {isim[:60]}")

    return eklenen


# ── KOSGEB PARSER ─────────────────────────────────────────────────

KOSGEB_KARA_LISTE = [
    "haber", "basın", "iletişim", "hakkında", "kariyer",
    "ihale", "personel", "404", "bulunamadı", "galeri",
]

KOSGEB_ANAHTAR = [
    "destek", "hibe", "program", "teşvik", "kredi", "finansman"
]


def kosgeb_tara(db: Client, mevcut: set) -> int:
    """KOSGEB destekler sayfasını tarar."""
    print(f"\n🏛️  KOSGEB")
    ana_url = "https://www.kosgeb.gov.tr/site/tr/genel/destekler"
    eklenen = 0

    try:
        r = requests.get(ana_url, headers=HEADERS, timeout=20, verify=False)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "lxml")
    except Exception as e:
        print(f"  ⚠️  Bağlantı hatası: {e}")
        return 0

    # Sayfa içindeki linkleri topla
    linkler = set()
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if not href.startswith("http"):
            href = "https://www.kosgeb.gov.tr" + href
        url_lower = href.lower()
        if any(k in url_lower for k in KOSGEB_KARA_LISTE):
            continue
        if any(k in url_lower for k in ["destek", "program", "hibe", "kredi"]):
            linkler.add(href)

    print(f"  {len(linkler)} link bulundu")

    for link in list(linkler)[:15]:
        try:
            pr = requests.get(link, headers=HEADERS, timeout=15, verify=False)
            pr.raise_for_status()
            psoup = BeautifulSoup(pr.text, "lxml")

            # Başlık çek
            baslik = None
            for tag in ["h1", "h2"]:
                el = psoup.find(tag)
                if el:
                    baslik = el.get_text(strip=True)
                    break

            if not baslik or len(baslik) < 10:
                continue

            sayfa_metin = psoup.get_text(separator=" ", strip=True).lower()
            if not any(k in sayfa_metin for k in KOSGEB_ANAHTAR):
                continue

            son_tarih = None
            tarih_m = re.search(r'(\d{1,2})\.(\d{1,2})\.(20\d{2})', sayfa_metin)
            if tarih_m:
                try:
                    gun = int(tarih_m.group(1))
                    ay = int(tarih_m.group(2))
                    yil = int(tarih_m.group(3))
                    dt = datetime(yil, ay, gun)
                    if dt > datetime.now():
                        son_tarih = dt.strftime("%Y-%m-%d")
                except:
                    pass

            urunler, etiketler = urun_ve_etiket_cikar(baslik)
            if "KOBİ" not in etiketler:
                etiketler.append("KOBİ")

            tesvik = {
                "isim": baslik[:250],
                "kurum": "KOSGEB",
                "basvuru_url": link,
                "son_basvuru_tarihi": son_tarih,
                "uygun_iller": [],
                "uygun_urunler": urunler,
                "etiketler": etiketler,
            }

            if baslik in mevcut:
                guncelle(db, tesvik)
            elif kaydet(db, tesvik, mevcut):
                eklenen += 1
                mevcut.add(baslik)
                print(f"  ➕ Eklendi: {baslik[:60]}")

            time.sleep(1)

        except Exception:
            continue

    return eklenen


# ── MAIN ──────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print(f"🌾 Teşvik Avcısı Bot v4 — {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 55)

    db = supabase_baglan()
    mevcut = mevcut_isimler(db)
    print(f"📊 Mevcut teşvik sayısı: {len(mevcut)}")

    toplam = 0
    toplam += yatirimadestek_tara(db, mevcut)
    toplam += kosgeb_tara(db, mevcut)

    suresi_gecenleri_pasife_al(db)

    print("\n" + "=" * 55)
    print(f"✅ Tamamlandı! {toplam} yeni teşvik eklendi.")
    print("=" * 55)


if __name__ == "__main__":
    main()