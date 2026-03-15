// lib/services/supabase_servisi.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tesvik_model.dart';
import '../models/profil_model.dart';

class SupabaseServisi {
  static final SupabaseServisi _instance = SupabaseServisi._internal();
  factory SupabaseServisi() => _instance;
  SupabaseServisi._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ── TEŞVİKLER ────────────────────────────────────────────

  Stream<List<TesvikModel>> tesviklerStream() {
    return _client
        .from('tesvikler')
        .stream(primaryKey: ['id']).map((jsonList) =>
            jsonList.map(TesvikModel.fromJson).toList());
  }

  Future<List<TesvikModel>> tesvikleriGetir() async {
    final response = await _client
        .from('tesvikler')
        .select('isim, basvuru_url, son_basvuru_tarihi, uygun_iller, uygun_urunler, etiketler, min_dekar')
        .eq('aktif', true);
    return (response as List<dynamic>)
        .map((json) => TesvikModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ── ANALİZ GEÇMİŞİ ───────────────────────────────────────

  Future<void> analiziKaydet(AnalizSonucu sonuc) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('analiz_gecmisi').insert({
        'user_id': user.id,
        'belge_ozeti': sonuc.belgeOzeti,
        'ai_sonucu': sonuc.metin,
        'basvuru_durumu': 'hazirlaniyor',
        'olusturulma': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analiz kaydedilemedi: $e');
    }
  }

  Future<List<AnalizGecmisi>> analizGecmisiniGetir() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final response = await _client
          .from('analiz_gecmisi')
          .select()
          .eq('user_id', user.id)
          .order('olusturulma', ascending: false)
          .limit(20);
      return (response as List<dynamic>)
          .map((json) => AnalizGecmisi.fromJson(
              json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Geçmiş getirilemedi: $e');
      return [];
    }
  }

  Future<void> analiziSil(String id) async {
    try {
      await _client.from('analiz_gecmisi').delete().eq('id', id);
    } catch (e) {
      debugPrint('Analiz silinemedi: $e');
    }
  }

  // Başvuru durumunu güncelle
  Future<void> basvuruDurumunuGuncelle(
      String id, String yeniDurum) async {
    try {
      await _client
          .from('analiz_gecmisi')
          .update({'basvuru_durumu': yeniDurum}).eq('id', id);
    } catch (e) {
      debugPrint('Durum güncellenemedi: $e');
    }
  }

  // ── PROFİL ───────────────────────────────────────────────

  Future<void> tokenKaydet(String token) async {
    try {
      await _client.from('user_tokens').upsert(
        {
          'token': token,
          'platform': 'android',
          'guncelleme': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('Token kaydedilemedi: $e');
    }
  }
}