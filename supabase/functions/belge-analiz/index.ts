// supabase/functions/belge-analiz/index.ts
//
// Gemini belge analizini sunucu tarafında çalıştırır. GEMINI_API_KEY yalnızca
// Edge Function secret'ında durur — istemci (APK) anahtarı hiç görmez (K3).
// Prompt ve teşvik listesi SUNUCUDA kurulur; istemci anahtarı keyfi Gemini
// çağrıları için kullanamaz. Giriş yapmış kullanıcı zorunludur.
//
// Deploy:
//   supabase functions deploy belge-analiz
//   supabase secrets set GEMINI_API_KEY=<anahtar>
// (SUPABASE_URL ve SUPABASE_ANON_KEY otomatik enjekte edilir.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-2.5-flash";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface ProfilGirdi {
  tipler?: string;
  il?: string;
  urunler?: string[];
  dekar?: number | null;
  kovanSayisi?: number | null;
  hayvanSayisi?: number | null;
}

function profilMetniKur(p: ProfilGirdi | null): string {
  if (!p) return "";
  const satirlar = [
    "ÇİFTÇİ PROFİLİ (sistemde kayıtlı):",
    `- Üretici tipi: ${p.tipler ?? ""}`,
    `- İl: ${p.il ?? ""}`,
    `- Ürünler: ${(p.urunler ?? []).join(", ")}`,
  ];
  if (p.dekar != null) satirlar.push(`- Arazi: ${p.dekar} dekar`);
  if (p.kovanSayisi != null) satirlar.push(`- Kovan: ${p.kovanSayisi} adet`);
  if (p.hayvanSayisi != null) satirlar.push(`- Hayvan: ${p.hayvanSayisi} adet`);
  return satirlar.join("\n") + "\n";
}

function tesvikSatiri(t: Record<string, unknown>): string {
  const isim = (t.isim as string) ?? "İsimsiz Teşvik";
  const link = (t.basvuru_url as string) ?? "Yok";
  const tarihRaw = t.son_basvuru_tarihi as string | null;
  const tarih = tarihRaw ? tarihRaw.split("T")[0].split(" ")[0] : "Sürekli";
  return `- İsim: ${isim} | Link: ${link} | Son Tarih: ${tarih}`;
}

function promptKur(profilMetni: string, tesvikMetni: string, dosyaAdi: string): string {
  const bugun = new Date().toISOString().split("T")[0];
  return `ÖNEMLİ GİZLİLİK TALİMATI: Bu belgede TC Kimlik No, ad-soyad, adres gibi kişisel veriler olabilir. Bu verileri ASLA kaydetme, tekrar etme veya analiz sonucuna dahil etme. Sadece tarımsal verileri (arazi büyüklüğü, ürün türü, il) çıkar.
Bugünün tarihi: ${bugun}. Sen profesyonel bir tarım danışmanısın.

${profilMetni}
Yüklenen belgeyi (${dosyaAdi || "belge"}) incele ve şunları yap:

1. Belgeden okunan bilgilerle profil bilgilerini karşılaştır, çiftçinin profilini özetle.
2. "SİSTEMDEKİ TEŞVİKLER" listesinden bu çiftçiye UYGUN olanları nedenleriyle açıkla.
3. UYGUN olmayan teşvikleri kısaca belirt.
4. Sadece UYGUN teşviklerin altına şu formatta link ekle:
[➔ HEMEN BAŞVURMAK İÇİN TIKLAYIN](linki_buraya_yaz)
5. Uygun bir teşvikin bitmesine 15 günden az kaldıysa metnin sonuna KRITIK_UYARI yaz.

SİSTEMDEKİ TEŞVİKLER:
${tesvikMetni}

---
Analizin en sonuna, belgeden çıkardığın tarımsal verileri TEK SATIR JSON olarak ekle:
PROFIL_JSON:{"il":"<sadece Türkiye il adı — örn: Ankara/Polatlı yazıyorsa sadece Ankara yaz>","uretici_tipleri":["ciftci","arici","hayvancilik","organik" değerlerinden uygun olanlar],"urunler":["<bulunan ürünler>"],"dekar":<sayı veya null>,"kovan_sayisi":<sayı veya null>,"hayvan_sayisi":<sayı veya null>}
Kural: uretici_tipleri boş olmasın, en az biri olsun. Belgede bilgi yoksa null yaz.`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Yalnızca POST" }, 405);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
  if (!GEMINI_API_KEY) {
    return jsonResponse({ error: "Sunucu yapılandırma hatası." }, 500);
  }

  // Kullanıcı doğrulama — giriş zorunlu
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return jsonResponse({ error: "Bu işlem için giriş yapmalısınız." }, 401);
  }

  // Girdi
  let body: {
    gorselBase64?: string;
    mimeType?: string;
    dosyaAdi?: string;
    profil?: ProfilGirdi | null;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Geçersiz istek gövdesi." }, 400);
  }
  const { gorselBase64, mimeType, dosyaAdi, profil } = body;
  if (!gorselBase64 || !mimeType) {
    return jsonResponse({ error: "Görsel verisi eksik." }, 400);
  }

  // Aktif teşvikleri sunucudan çek (prompt sunucuda kurulur)
  let tesvikMetni = "Sistemde aktif teşvik bulunamadı.";
  try {
    const { data: tesvikler } = await supabase
      .from("tesvikler")
      .select("isim, basvuru_url, son_basvuru_tarihi")
      .eq("aktif", true);
    if (tesvikler && tesvikler.length > 0) {
      tesvikMetni = tesvikler.map(tesvikSatiri).join("\n");
    }
  } catch (_) {
    // teşvik çekilemezse boş listeyle devam
  }

  const prompt = promptKur(
    profilMetniKur(profil ?? null),
    tesvikMetni,
    dosyaAdi ?? "",
  );

  // Gemini çağrısı
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
  const payload = {
    contents: [{
      parts: [
        { text: prompt },
        { inline_data: { mime_type: mimeType, data: gorselBase64 } },
      ],
    }],
  };

  let data: Record<string, any>;
  try {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    data = await resp.json();
    if (!resp.ok) {
      const msg = JSON.stringify(data).toLowerCase();
      if (msg.includes("429") || msg.includes("quota") || resp.status === 429) {
        return jsonResponse(
          { error: "Günlük AI analiz limiti doldu. Lütfen birkaç dakika bekleyin." },
          429,
        );
      }
      return jsonResponse({ error: "AI hatası." }, 502);
    }
  } catch (_) {
    return jsonResponse({ error: "AI servisine ulaşılamadı." }, 502);
  }

  // Yanıt guard (boş / safety block)
  const block = data?.promptFeedback?.blockReason;
  if (block) {
    return jsonResponse(
      { error: `İçerik işlenemedi (blockReason: ${block}).` },
      422,
    );
  }
  const metin = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!metin) {
    return jsonResponse({ error: "Analiz sonucu alınamadı." }, 502);
  }

  return jsonResponse({ metin });
});
