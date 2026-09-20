import type { APIRoute } from 'astro';
import { createSSRClient, createServiceClient } from '../../../lib/ssr-client';

export const PUT: APIRoute = async ({ request, params }) => {
  // Auth check
  const ssr = createSSRClient({ request } as any);
  const { data: { user } } = await ssr.supabase.auth.getUser();
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });

  const catchId = params.id;
  if (!catchId) return new Response(JSON.stringify({ error: 'Missing ID' }), { status: 400 });

  const body = await request.json();
  const admin = createServiceClient();

  // Verify ownership
  const { data: existing } = await admin
    .from('catches')
    .select('id, user_id')
    .eq('id', catchId)
    .eq('user_id', user.id)
    .single();

  if (!existing) return new Response(JSON.stringify({ error: 'Fang nicht gefunden' }), { status: 404 });

  // Build update object (only allowed fields)
  const update: Record<string, any> = {};
  if (body.species !== undefined) update.species = body.species;
  if (body.weight_kg !== undefined) update.weight_kg = body.weight_kg;
  if (body.length_cm !== undefined) update.length_cm = body.length_cm;
  if (body.bait !== undefined) update.bait = body.bait;
  if (body.method !== undefined) update.method = body.method;
  if (body.water_name !== undefined) update.water_name = body.water_name;
  if (body.water_id !== undefined) update.water_id = body.water_id;
  if (body.water_temp_c !== undefined) update.water_temp_c = body.water_temp_c;
  if (body.notes !== undefined) update.notes = body.notes;
  if (body.photos !== undefined) update.photos = body.photos;
  if (body.caught_at !== undefined) update.caught_at = body.caught_at;
  if (body.catch_release !== undefined) update.catch_release = body.catch_release;

  if (Object.keys(update).length === 0) {
    return new Response(JSON.stringify({ error: 'Keine Änderungen' }), { status: 400 });
  }

  const { error } = await admin
    .from('catches')
    .update(update)
    .eq('id', catchId)
    .eq('user_id', user.id);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 });
};
