export interface DraftEntry {
  client_uuid: string;
  p_data: Record<string, unknown>;
  created_at: string;
}

const DB_NAME = 'carp24-offline';
const DB_VERSION = 1;
const STORE_NAME = 'drafts';

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'client_uuid' });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function queueDraft(draft: DraftEntry): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    store.put(draft);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export async function getDrafts(): Promise<DraftEntry[]> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly');
    const store = tx.objectStore(STORE_NAME);
    const request = store.getAll();
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function removeDraft(client_uuid: string): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    store.delete(client_uuid);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export async function syncDrafts(): Promise<{ synced: number; failed: number }> {
  const drafts = await getDrafts();
  let synced = 0;
  let failed = 0;

  const SUPABASE_URL = (window as any).__SUPABASE_URL__ || '';
  const SUPABASE_ANON_KEY = (window as any).__SUPABASE_ANON_KEY__ || '';

  function getSupabase() {
    if ((window as any).__supabase) return (window as any).__supabase;
    if (typeof (window as any).supabase !== 'undefined' && (window as any).supabase.createClient) {
      (window as any).__supabase = (window as any).supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      });
      return (window as any).__supabase;
    }
    return null;
  }

  const sb = getSupabase();
  if (!sb) return { synced: 0, failed: drafts.length };

  for (const draft of drafts) {
    try {
      const { error } = await sb.rpc('sync_catch', {
        p_client_uuid: draft.client_uuid,
        p_data: draft.p_data,
      });
      if (error) {
        failed++;
      } else {
        await removeDraft(draft.client_uuid);
        synced++;
      }
    } catch {
      failed++;
    }
  }

  return { synced, failed };
}
