# scraper/push_bildirim.py
# Teşvik Avcısı — Push Bildirim Servisi
# Her teşvik için 15, 7, 3 gün eşiklerinde sadece BİR KEZ bildirim gönderir.

import os
import json
import requests
from datetime import datetime, timedelta
from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
FIREBASE_SERVICE_ACCOUNT = os.environ.get("FIREBASE_SERVICE_ACCOUNT")


def firebase_access_token_al() -> str:
    import google.auth.transport.requests
    from google.oauth2 import service_account

    sa_info = json.loads(FIREBASE_SERVICE_ACCOUNT)
    credentials = service_account.Credentials.from_service_account_info(
        sa_info,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"],
    )
    request = google.auth.transport.requests.Request()
    credentials.refresh(request)
    return credentials.token


def fcm_bildirim_gonder(token: str, baslik: str, icerik: str, access_token: str) -> bool:
    project_id = json.loads(FIREBASE_SERVICE_ACCOUNT)["project_id"]
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"

    payload = {
        "message": {
            "token": token,
            "notification": {
                "title": baslik,
                "body": icerik,
            },
            "android": {
                "priority": "high",
                "notification": {
                    "channel_id": "high_importance_channel",
                    "sound": "default",
                },
            },
        }
    }

    response = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=10,
    )
    return response.status_code == 200


def bildirim_gonderildi_mi(db, tesvik_id: str, bildirim_turu: str) -> bool:
    """Bu teşvik için bu eşikte daha önce bildirim gönderildi mi?"""
    try:
        r = db.table("gonderilen_bildirimler")\
            .select("id")\
            .eq("tesvik_id", tesvik_id)\
            .eq("bildirim_turu", bildirim_turu)\
            .execute()
        return len(r.data or []) > 0
    except Exception as e:
        # Hata → "gönderilmedi" varsay (bildirim atlanmasındansa tekrar denensin)
        print(f"  ⚠️  Bildirim durumu sorgulanamadı ({tesvik_id}): {e}")
        return False


def bildirim_kaydet(db, tesvik_id: str, bildirim_turu: str):
    """Gönderilen bildirimi kaydet — bir daha gönderilmesin."""
    try:
        db.table("gonderilen_bildirimler").insert({
            "tesvik_id": tesvik_id,
            "bildirim_turu": bildirim_turu,
            "gonderilme_tarihi": datetime.now().date().isoformat(),
        }).execute()
    except Exception as e:
        print(f"  ⚠️  Bildirim kaydedilemedi: {e}")


# ── PROFİL EŞLEŞTİRME ──────────────────────────────────────────────
# Uygulamadaki eslesme_servisi.dart'ın SADELEŞTİRİLMİŞ Python portu.
# Bildirim için "bu teşvik bu profile uyuyor mu?" boolean'ı yeterli; Dart'taki
# puanlama yerine eliminasyon kriterleri (il + ürün) kullanılır.
# DİKKAT: Dart tarafı değişirse burayı da güncelle (iki ayrı implementasyon).

def _il_anahtar(s: str) -> str:
    """Türkçe büyük/küçük harf duyarsız il karşılaştırma anahtarı (ilEslesir portu)."""
    if not s:
        return ""
    harita = {"ç": "c", "Ç": "c", "ğ": "g", "Ğ": "g", "ı": "i", "İ": "i",
              "I": "i", "ö": "o", "Ö": "o", "ş": "s", "Ş": "s", "ü": "u", "Ü": "u"}
    return "".join(harita.get(ch, ch) for ch in s.strip()).lower()


def tesvik_profile_uyuyor(tesvik: dict, profil: dict) -> bool:
    # İL: teşvikin uygun illeri varsa profilin ili eşleşmeli (boşsa tüm Türkiye)
    iller = tesvik.get("uygun_iller") or []
    if iller:
        p_il = _il_anahtar(profil.get("il") or "")
        if not p_il or not any(_il_anahtar(i) == p_il for i in iller):
            return False
    # ÜRÜN: teşvikin uygun ürünleri varsa en az biri profilde olmalı
    urunler = tesvik.get("uygun_urunler") or []
    if urunler:
        p_urunler = {u.casefold() for u in (profil.get("urunler") or [])}
        if not p_urunler or not any(u.casefold() in p_urunler for u in urunler):
            return False
    return True


def main():
    print("=" * 55)
    print(f"🔔 Push Bildirim Servisi — {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 55)

    db = create_client(SUPABASE_URL, SUPABASE_KEY)
    bugun = datetime.now().date()

    # Eşikler: kaç gün kaldığında bildirim gönderilsin
    ESIKLER = {
        3:  ("3gun",  "🔴"),
        7:  ("7gun",  "🟠"),
        15: ("15gun", "🟡"),
    }

    bildirim_tesvikler = []

    # 15 gün içinde biten teşvikleri çek
    try:
        hedef_bitis = (bugun + timedelta(days=15)).strftime("%Y-%m-%d")
        r = db.table("tesvikler")\
            .select("id, isim, son_basvuru_tarihi, uygun_iller, uygun_urunler")\
            .eq("aktif", True)\
            .gte("son_basvuru_tarihi", bugun.strftime("%Y-%m-%d"))\
            .lte("son_basvuru_tarihi", hedef_bitis)\
            .execute()

        for t in (r.data or []):
            tarih = datetime.strptime(t["son_basvuru_tarihi"], "%Y-%m-%d").date()
            kalan = (tarih - bugun).days

            # En acil (en küçük) eşiği seç: kalan <= esik. Böylece bot bir gün
            # çalışmasa bile eşik kaçmaz (ör. kalan=6 → 7gün eşiği yine tetiklenir).
            esik_gun = next((e for e in sorted(ESIKLER) if kalan <= e), None)
            if esik_gun is None:
                continue
            esik_tur, emoji = ESIKLER[esik_gun]

            # Daha önce bu eşik için bildirim gönderildiyse atla (spam önleme)
            if bildirim_gonderildi_mi(db, t["id"], esik_tur):
                print(f"  ⏭️  Zaten gönderildi ({esik_gun} gün): {t['isim'][:40]}")
            else:
                bildirim_tesvikler.append({
                    "id": t["id"],
                    "isim": t["isim"],
                    "kalan_gun": kalan,
                    "esik_tur": esik_tur,
                    "emoji": emoji,
                    "uygun_iller": t.get("uygun_iller") or [],
                    "uygun_urunler": t.get("uygun_urunler") or [],
                })
                print(f"  ⏰ {kalan} gün kaldı (eşik {esik_gun}): {t['isim'][:40]}")

    except Exception as e:
        print(f"  ⚠️  Sorgu hatası: {e}")

    if not bildirim_tesvikler:
        print("✅ Bugün gönderilecek yeni bildirim yok.")
        return

    # Profilleri çek (user_id → profil); tercih + eşleşme için
    try:
        prof_r = db.table("kullanici_profilleri")\
            .select("user_id, il, urunler, bildirim_son_tarih").execute()
        profiller = {p["user_id"]: p
                     for p in (prof_r.data or []) if p.get("user_id")}
    except Exception as e:
        print(f"  ⚠️  Profiller alınamadı: {e}")
        return

    # Token'ları çek ve user_id'ye grupla (misafir/null token atlanır)
    try:
        tok_r = db.table("user_tokens").select("token, user_id").execute()
    except Exception as e:
        print(f"  ⚠️  Token listesi alınamadı: {e}")
        return

    kullanici_tokenlari: dict = {}
    for row in (tok_r.data or []):
        uid, token = row.get("user_id"), row.get("token")
        if uid and token:
            kullanici_tokenlari.setdefault(uid, []).append(token)

    if not kullanici_tokenlari:
        print("⚠️  Kullanıcıya bağlı token yok (kişisel bildirim gönderilemez).")
        return

    print(f"\n📱 {len(kullanici_tokenlari)} kayıtlı kullanıcı için eşleştiriliyor...\n")

    try:
        access_token = firebase_access_token_al()
    except Exception as e:
        print(f"  ⚠️  Firebase token alınamadı: {e}")
        return

    basarili = 0
    for tesvik in bildirim_tesvikler:
        kalan = tesvik["kalan_gun"]
        baslik = f"{tesvik['emoji']} Son {kalan} Gün!"
        icerik = f"{tesvik['isim'][:60]} için başvuru süresi dolmak üzere."

        hedef = 0
        for uid, tokenlar in kullanici_tokenlari.items():
            profil = profiller.get(uid)
            if not profil:
                continue  # profili yok → kişiselleştirilemez
            if not profil.get("bildirim_son_tarih", True):
                continue  # kullanıcı son-tarih bildirimini kapatmış (D4)
            if not tesvik_profile_uyuyor(tesvik, profil):
                continue  # O6: profile uymuyor
            for token in tokenlar:
                if fcm_bildirim_gonder(token, baslik, icerik, access_token):
                    basarili += 1
                    hedef += 1

        print(f"  📤 {tesvik['isim'][:40]}: {hedef} cihaza gönderildi")
        # Eşik bazında bir kez işaretle (global). NOT: bu eşiğe sonradan giren
        # kullanıcılar bu turu kaçırabilir; bot günlük çalıştığı için kabul edilir.
        bildirim_kaydet(db, tesvik["id"], tesvik["esik_tur"])

    print(f"\n✅ {basarili} bildirim gönderildi.")
    print("=" * 55)


if __name__ == "__main__":
    main()