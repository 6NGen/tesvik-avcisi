-- ════════════════════════════════════════════════════════════════
-- BİLDİRİM BACKEND MIGRATION (D4 ucu + O6)
-- Supabase SQL Editor'da çalıştır. Kod (uygulama + push_bildirim.py)
-- bu kolonlara güveniyor; YENİ APP BUILD KULLANILMADAN ÖNCE uygula.
-- ════════════════════════════════════════════════════════════════

-- 1) Token'ı kullanıcıya bağla (O6 + tercih için zorunlu).
--    Misafir token'ları için nullable. Kullanıcı silinince token da silinsin.
alter table public.user_tokens
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- 2) Bildirim tercihleri — profile gömülü (en az tablo).
alter table public.kullanici_profilleri
  add column if not exists bildirim_son_tarih boolean not null default true;
alter table public.kullanici_profilleri
  add column if not exists bildirim_yeni_hibe boolean not null default true;

-- 3) RLS: uygulama (anon+auth) kendi token'ını yazabilsin.
--    NOT: user_tokens'ta zaten bir insert/update politikası varsa, user_id
--    yazımına izin verdiğinden emin ol. Aşağıdaki politika, kullanıcının
--    yalnızca kendi user_id'siyle (veya misafir olarak null) yazmasına izin verir.
--    Mevcut politikalarınla çakışırsa önce eskiyi DROP et.
-- drop policy if exists "user_tokens_yaz" on public.user_tokens;
-- create policy "user_tokens_yaz" on public.user_tokens
--   for insert with check (user_id is null or auth.uid() = user_id);
-- create policy "user_tokens_guncelle" on public.user_tokens
--   for update using (user_id is null or auth.uid() = user_id);

-- ════════════════════════════════════════════════════════════════
-- Geri alma (gerekirse):
-- alter table public.user_tokens drop column if exists user_id;
-- alter table public.kullanici_profilleri drop column if exists bildirim_son_tarih;
-- alter table public.kullanici_profilleri drop column if exists bildirim_yeni_hibe;
-- ════════════════════════════════════════════════════════════════
