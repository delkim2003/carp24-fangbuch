import { supabase } from './supabase-client';

export function genClientUuid(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  if (typeof crypto !== "undefined" && typeof crypto.getRandomValues === "function") {
    const buf = new Uint8Array(16);
    crypto.getRandomValues(buf);
    buf[6] = (buf[6] & 0x0f) | 0x40;
    buf[8] = (buf[8] & 0x3f) | 0x80;
    const hex = Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
    return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-" + hex.slice(12, 16) + "-" + hex.slice(16, 20) + "-" + hex.slice(20);
  }
  return "f" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10);
}

export interface Water {
  name: string;
  lat: number;
  lng: number;
}

export interface CatchInput {
  catch_ts: string;
  species: string;
  weight_kg: number;
  length_cm?: number;
  bait?: string;
  method?: string;
  notes?: string;
  lat?: number;
  lng?: number;
  water_name?: string;
  water_id?: string;
  photos?: string[];
}

export async function searchWaters(query: string): Promise<Water[]> {
  try {
    const { data, error } = await supabase.functions.invoke('gewaesser-search', {
      body: { query },
    });
    if (error) {
      console.error('searchWaters error:', error.message);
      return [];
    }
    return (data as Water[]) ?? [];
  } catch (err) {
    console.error('searchWaters exception:', err);
    return [];
  }
}

export async function saveCatch(
  input: CatchInput
): Promise<{ id?: string; error?: string }> {
  const client_uuid = genClientUuid();
  const p_data = {
    ...input,
    draft: false,
    weather_auto: false,
    client_updated_at: new Date().toISOString(),
  };

  const { data: catch_id, error: syncError } = await supabase.rpc('sync_catch', {
    p_client_uuid: client_uuid,
    p_data,
  });

  if (syncError) {
    return { error: syncError.message };
  }

  // sync_catch mit draft:false veröffentlicht den Fang direkt (publish_catch
  // würde "catch already published" werfen). publish_catch ist NUR für
  // Draft->Published-Flows nötig (draft:true angelegt, später veröffentlicht).
  return { id: catch_id as string };
}
