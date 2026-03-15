# scraper/push_bildirim.py
# Teşvik Avcısı — Push Bildirim Servisi
# Her gece çalışır, son tarihi yaklaşan teşvikler için
# kullanıcılara FCM bildirimi gönderir.

import os
import json
import requests
from datetime import datetime, timedelta
from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
FIREBASE_SERVICE_ACCOUNT = os.environ.get("FIREBASE_SERVICE_ACCOUNT")

# ── FIREBASE TOKEN AL ─────────────────────────────────────────────

def firebase_access_token_al() -> str:
    """Service account JSON ile Firebase access token alır."""
    import google.auth
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
    """Tek bir FCM token'a bildirim gönderir."""
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


# ── ANA FONKSİYON ─────────────────────────────────────────────────

def main():
    print("=" * 55)
    print(f"🔔 Push Bildirim Servisi — {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print("=" * 55)

    db = create_client(SUPABASE_URL, SUPABASE_KEY)
    bugun = datetime.now().date()

    # Son tarihi yaklaşan teşvikleri bul (3, 7, 15 gün)
    esikler = [3, 7, 15]
    bildirim_tesvikler = []

    for gun in esikler:
        hedef_tarih = (bugun + timedelta(days=gun)).strftime("%Y-%m-%d")
        try:
            r = db.table("tesvikler")\
                .select("isim, son_basvuru_tarihi")\
                .eq("aktif", True)\
                .eq("son_basvuru_tarihi", hedef_tarih)\
                .execute()

            for t in (r.data or []):
                bildirim_tesvikler.append({
                    "isim": t["isim"],
                    "kalan_gun": gun,
                })
                print(f"  ⏰ {gun} gün kaldı: {t['isim'][:50]}")
        except Exception as e:
            print(f"  ⚠️  Sorgu hatası: {e}")

    if not bildirim_tesvikler:
        print("✅ Bugün bildirim gönderilecek teşvik yok.")
        return

    # Tüm FCM tokenları al
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

    # Firebase access token al
    try:
        access_token = firebase_access_token_al()
    except Exception as e:
        print(f"  ⚠️  Firebase token alınamadı: {e}")
        return

    # Her teşvik için bildirim gönder
    basarili = 0
    for tesvik in bildirim_tesvikler:
        kalan = tesvik["kalan_gun"]
        baslik = f"⏰ Son {kalan} Gün!"
        icerik = f'{tesvik["isim"][:60]} için başvuru süresi dolmak üzere.'

        for token in tokenlar:
            if fcm_bildirim_gonder(token, baslik, icerik, access_token):
                basarili += 1

    print(f"\n✅ {basarili} bildirim gönderildi.")
    print("=" * 55)


if __name__ == "__main__":
    main()