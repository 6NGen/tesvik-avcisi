// lib/services/supabase_servisi.dart
//
// Yazma işlemleri hata durumunda Exception fırlatır; çağıran ekran kullanıcıya
// gösterir. (Eskiden hatalar yutuluyor, başarısız kayıtta bile "eklendi"
// mesajı çıkıyordu.)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/tarih.dart';
import '../models/tesvik_model.dart';

class SupabaseServisi {
  static final SupabaseServisi _instance = SupabaseServisi._internal();
  factory SupabaseServisi() => _instance;
  SupabaseServisi._internal();

  SupabaseClient get _client => Supabase.instance.client;

  String _kullaniciId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Bu işlem için giriş yapmalısın.');
    return id;
  }

  // ── TEŞVİKLER ────────────────────────────────────────────

  Stream<List<TesvikModel>> tesviklerStream() {
    return _client
        .from('tesvikler')
        .stream(primaryKey: ['id'])
        .eq('aktif', true)
        .map((jsonList) => jsonList.map(TesvikModel.fromJson).toList());
  }

  // ── TAKİP / ANALİZ GEÇMİŞİ ───────────────────────────────

  Future<void> analiziKaydet(AnalizSonucu sonuc) async {
    final userId = _kullaniciId();
    try {
      await _client.from('analiz_gecmisi').insert({
        'user_id': userId,
        'belge_ozeti': sonuc.belgeOzeti,
        'ai_sonucu': sonuc.metin,
        'basvuru_durumu': BasvuruDurumu.hazirlaniyor.name,
        'olusturulma': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analiz kaydedilemedi: $e');
      throw Exception('Kayıt yapılamadı. İnternet bağlantını kontrol et.');
    }
  }

  /// "Başvuruya başladım" — teşviki takip listesine ekler.
  /// Aynı teşvik zaten listedeyse false döner (mükerrer kayıt açılmaz).
  Future<bool> takibeEkle(TesvikModel tesvik) async {
    final userId = _kullaniciId();
    try {
      final mevcut = await _client
          .from('analiz_gecmisi')
          .select('id')
          .eq('user_id', userId)
          .eq('belge_ozeti', tesvik.isim)
          .limit(1);
      if ((mevcut as List).isNotEmpty) return false;

      final sonTarih = tesvik.sonBasvuruTarihi;
      await _client.from('analiz_gecmisi').insert({
        'user_id': userId,
        'belge_ozeti': tesvik.isim,
        'ai_sonucu': [
          '## ${tesvik.isim}',
          '**Kurum:** ${tesvik.kurum ?? "Belirtilmemiş"}',
          '**Son başvuru:** ${sonTarih != null ? tarihUzun(sonTarih) : "Süresiz"}',
          if (tesvik.basvuruUrl != null)
            '[Resmi başvuru sayfası](${tesvik.basvuruUrl})',
        ].join('\n\n'),
        'basvuru_durumu': BasvuruDurumu.hazirlaniyor.name,
        'olusturulma': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Takibe eklenemedi: $e');
      throw Exception('Takibe eklenemedi. İnternet bağlantını kontrol et.');
    }
  }

  Future<List<AnalizGecmisi>> analizGecmisiniGetir() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await _client
        .from('analiz_gecmisi')
        .select('id, belge_ozeti, ai_sonucu, basvuru_durumu, olusturulma')
        .eq('user_id', userId)
        .order('olusturulma', ascending: false)
        .limit(100);
    return (response as List)
        .map((j) => AnalizGecmisi.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> analiziSil(String id) async {
    final userId = _kullaniciId();
    try {
      await _client
          .from('analiz_gecmisi')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Analiz silinemedi: $e');
      throw Exception('Kayıt silinemedi.');
    }
  }

  Future<void> basvuruDurumunuGuncelle(String id, BasvuruDurumu durum) async {
    final userId = _kullaniciId();
    try {
      await _client
          .from('analiz_gecmisi')
          .update({'basvuru_durumu': durum.name})
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Durum güncellenemedi: $e');
      throw Exception('Durum güncellenemedi.');
    }
  }

  // ── FCM TOKEN ────────────────────────────────────────────

  Future<void> tokenKaydet(String token) async {
    try {
      // user_id çağrı anındaki oturuma göre yazılır: giriş varsa kullanıcı,
      // misafirse null. Bu sayede push servisi token'ı profile bağlayabilir.
      await _client.from('user_tokens').upsert(
        {
          'token': token,
          'user_id': _client.auth.currentUser?.id,
          'platform': defaultTargetPlatform.name,
          'guncelleme': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('Token kaydedilemedi: $e');
    }
  }
}
