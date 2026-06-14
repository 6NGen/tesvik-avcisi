-- ════════════════════════════════════════════════════════════════
-- "YENİ HİBE" BİLDİRİMİ — İLK ÇALIŞMA SPAM'INI ÖNLEME
-- Supabase SQL Editor'da BİR KEZ çalıştır (push_bildirim.py güncellemesinden
-- ÖNCE veya botun ilk çalışmasından önce).
--
-- push_bildirim.py artık "aktif olup 'yeni' bildirimi yapılmamış" her teşvik
-- için yeni-hibe bildirimi gönderir. Bu satır olmadan, ilk çalıştırmada MEVCUT
-- tüm teşvikler "yeni" sayılıp kullanıcılara toplu bildirim gider (spam).
-- Bu insert, şu anki aktif teşvikleri "zaten duyuruldu" olarak işaretler.
-- ════════════════════════════════════════════════════════════════

insert into public.gonderilen_bildirimler (tesvik_id, bildirim_turu, gonderilme_tarihi)
select id, 'yeni', current_date
from public.tesvikler
where aktif = true;

-- NOT: Yalnızca BİR KEZ çalıştır. Tekrar çalıştırmak zararsız ama mükerrer
-- satır ekler (push_bildirim.py count>0 kontrolü kullandığı için mantık bozulmaz).
-- Doğrulama:
--   select count(*) from gonderilen_bildirimler where bildirim_turu = 'yeni';
