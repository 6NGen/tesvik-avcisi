-- KOSGEB çöp kayıtlarını pasife alır (Supabase → SQL Editor'de BİR KEZ çalıştır).
--
-- Eski KOSGEB parser'ı anahtar kelimeyi sayfa metninde aradığı için
-- /destekdetay/ altındaki gazete ilanlarını, e-dergileri ve finansal oran
-- sayfalarını "teşvik" diye kaydetti. Parser düzeltildi (başlık filtresi,
-- scraper.py → kosgeb_baslik_gecerli); bu sorgu mevcut kayıtları temizler.
-- Silme yok: yalnızca aktif=false. Geri almak için aktif=true yapmak yeterli.

-- 1) Önce kontrol et: pasife alınacak kayıtlar
select id, isim, basvuru_url
from tesvikler
where kurum = 'KOSGEB'
  and aktif
  and (
    isim !~* '(destek|program|kredi|hibe|teşvik|tesvik|finansman|fon)'
    or isim like '%&nbsp%'
  )
order by isim;

-- 2) Aynı programın eski adla kalmış kopyası (destekdetay/9414)
select id, isim, basvuru_url from tesvikler
where kurum = 'KOSGEB' and aktif and basvuru_url like '%/destekdetay/9414/yapay-zek-kredi-pr%';

-- 3) Uygula
update tesvikler
set aktif = false, guncelleme = now()
where kurum = 'KOSGEB'
  and aktif
  and (
    isim !~* '(destek|program|kredi|hibe|teşvik|tesvik|finansman|fon)'
    or isim like '%&nbsp%'
    or basvuru_url like '%/destekdetay/9414/yapay-zek-kredi-pr%'
  );
