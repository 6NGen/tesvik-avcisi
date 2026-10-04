// lib/providers/takip_provider.dart
//
// Başvuru takibi / analiz geçmişi. Oturumdaki kullanıcıya bağlıdır: kullanıcı
// değişince liste yeniden çekilir (eskiden önbellekte kalıp bir sonraki
// kullanıcıya önceki kullanıcının kayıtları gösteriliyordu).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tesvik_model.dart';
import '../services/supabase_servisi.dart';
import 'auth_provider.dart';

class TakipNotifier extends AsyncNotifier<List<AnalizGecmisi>> {
  final _db = SupabaseServisi();

  @override
  Future<List<AnalizGecmisi>> build() async {
    final userId = ref.watch(kullaniciIdProvider);
    if (userId == null) return const [];
    return _db.analizGecmisiniGetir();
  }

  Future<void> yenile() async {
    state = const AsyncLoading<List<AnalizGecmisi>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_db.analizGecmisiniGetir);
  }

  /// Optimistik silme; hata olursa eski listeye döner ve hatayı fırlatır.
  Future<void> sil(String id) async {
    final onceki = state.valueOrNull ?? const [];
    state = AsyncData(onceki.where((a) => a.id != id).toList());
    try {
      await _db.analiziSil(id);
    } catch (_) {
      state = AsyncData(onceki);
      rethrow;
    }
  }

  Future<void> durumGuncelle(String id, BasvuruDurumu durum) async {
    final onceki = state.valueOrNull ?? const [];
    state = AsyncData([
      for (final a in onceki) a.id == id ? a.durumla(durum) : a,
    ]);
    try {
      await _db.basvuruDurumunuGuncelle(id, durum);
    } catch (_) {
      state = AsyncData(onceki);
      rethrow;
    }
  }

  /// Teşviki takibe ekler; zaten listedeyse false.
  Future<bool> tesvikEkle(TesvikModel tesvik) async {
    final eklendi = await _db.takibeEkle(tesvik);
    if (eklendi) ref.invalidateSelf();
    return eklendi;
  }
}

final takipProvider =
    AsyncNotifierProvider<TakipNotifier, List<AnalizGecmisi>>(
  TakipNotifier.new,
);
