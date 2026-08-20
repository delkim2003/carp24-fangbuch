import { supabase } from './supabase-client';

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
  const client_uuid = crypto.randomUUID();
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

  const { error: pubError } = await supabase.rpc('publish_catch', {
    p_catch_id: catch_id,
  });

  if (pubError) {
    return { id: catch_id as string, error: pubError.message };
  }

  return { id: catch_id as string };
}
