// lib/providers/profil_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profil_model.dart';

class ProfilNotifier extends StateNotifier<AsyncValue<ProfilModel?>> {
  ProfilNotifier() : super(const AsyncValue.loading()) {
    _profilYukle();
  }

  final _client = Supabase.instance.client;

  // Mevcut profili Supabase'den yükle
  Future<void> _profilYukle() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final response = await _client
          .from('kullanici_profilleri')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        state = const AsyncValue.data(null); // Profil yok → tamamlama ekranı
      } else {
        state = AsyncValue.data(
            ProfilModel.fromJson(response as Map<String, dynamic>));
      }
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  // Profili kaydet veya güncelle
  Future<bool> profilKaydet(ProfilModel profil) async {
    try {
      await _client.from('kullanici_profilleri').upsert(
        profil.toJson(),
        onConflict: 'user_id',
      );
      state = AsyncValue.data(profil);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Profili sıfırla (çıkış yapınca)
  void sifirla() => state = const AsyncValue.data(null);
}

final profilProvider =
    StateNotifierProvider<ProfilNotifier, AsyncValue<ProfilModel?>>(
  (ref) => ProfilNotifier(),
);

// Profil var mı yok mu — router'da kullanılır
final profilVarMiProvider = Provider<bool>((ref) {
  return ref.watch(profilProvider).value != null;
});