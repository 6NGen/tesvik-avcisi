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
    except:
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
            .select("id, isim, son_basvuru_tarihi")\
            .eq("aktif", True)\
            .gte("son_basvuru_tarihi", bugun.strftime("%Y-%m-%d"))\
            .lte("son_basvuru_tarihi", hedef_bitis)\
            .execute()

        for t in (r.data or []):
            tarih = datetime.strptime(t["son_basvuru_tarihi"], "%Y-%m-%d").date()
            kalan = (tarih - bugun).days

            # Hangi eşiğe denk geliyor?
            for esik_gun, (esik_tur, emoji) in ESIKLER.items():
                if kalan == esik_gun:
                    # Daha önce bu eşik için bildirim gönderildiyse atla
                    if bildirim_gonderildi_mi(db, t["id"], esik_tur):
                        print(f"  ⏭️  Zaten gönderildi ({esik_gun} gün): {t['isim'][:40]}")
                    else:
                        bildirim_tesvikler.append({
                            "id": t["id"],
                            "isim": t["isim"],
                            "kalan_gun": kalan,
                            "esik_tur": esik_tur,
                            "emoji": emoji,
                        })
                        print(f"  ⏰ {kalan} gün kaldı: {t['isim'][:40]}")
                    break

    except Exception as e:
        print(f"  ⚠️  Sorgu hatası: {e}")

    if not bildirim_tesvikler:
        print("✅ Bugün gönderilecek yeni bildirim yok.")
        return

    # FCM tokenları al
    try:
        tokens_r = db.table("user_tokens").select("token").execute()
        tokenlar = [r["token"] for r in (tokens_r.data or [])]
    except Exception as e:
        print(f"  ⚠️  Token listesi alınamadı: {e}")
        return

    if not tokenlar:
        print("⚠️  Kayıtlı kullanıcı tokeni yok.")
        return

    print(f"\n📱 {len(tokenlar)} kullanıcıya bildirim gönderiliyor...\n")

    try:
        access_token = firebase_access_token_al()
    except Exception as e:
        print(f"  ⚠️  Firebase token alınamadı: {e}")
        return

    basarili = 0
    for tesvik in bildirim_tesvikler:
        kalan = tesvik["kalan_gun"]
        emoji = tesvik["emoji"]
        baslik = f"{emoji} Son {kalan} Gün!"
        icerik = f'{tesvik["isim"][:60]} için başvuru süresi dolmak üzere.'

        for token in tokenlar:
            if fcm_bildirim_gonder(token, baslik, icerik, access_token):
                basarili += 1

        # Gönderildi olarak kaydet
        bildirim_kaydet(db, tesvik["id"], tesvik["esik_tur"])

    print(f"\n✅ {basarili} bildirim gönderildi.")
    print("=" * 55)


if __name__ == "__main__":
    main()