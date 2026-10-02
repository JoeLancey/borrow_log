// supabase/functions/send_email/index.ts
//
// Sends a transactional email via Brevo. Callable only by staff.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
    const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
    const BREVO_SENDER_EMAIL = Deno.env.get('BREVO_SENDER_EMAIL');
    const BREVO_SENDER_NAME =
      Deno.env.get('BREVO_SENDER_NAME') ?? 'BORROW LOG';

    if (!SUPABASE_URL || !SERVICE_ROLE || !ANON_KEY) {
      return json({ error: 'Missing Supabase configuration' }, 500);
    }
    if (!BREVO_API_KEY || !BREVO_SENDER_EMAIL) {
      return json({ error: 'Missing Brevo configuration' }, 500);
    }

    // -----------------------------------------------------------------
    // 1. Verify caller is staff.
    // -----------------------------------------------------------------
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return json({ error: 'Authorization required' }, 401);
    }

    const jwt = authHeader.substring('Bearer '.length).trim();
    if (!jwt) {
      return json({ error: 'Authorization required' }, 401);
    }

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    const {
      data: { user: caller },
      error: callerErr,
    } = await callerClient.auth.getUser();

    if (callerErr || !caller) {
      return json({ error: 'Invalid token' }, 401);
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE);
    const { data: callerProfile } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', caller.id)
      .maybeSingle();

    if (callerProfile?.role !== 'staff') {
      return json({ error: 'Staff access required' }, 403);
    }

    // -----------------------------------------------------------------
    // 2. Parse body
    // -----------------------------------------------------------------
    const body = await req.json();
    const { to, subject, html, text } = body ?? {};

    if (!to || !subject || (!html && !text)) {
      return json(
        { error: 'Missing required fields: to, subject, html or text' },
        400,
      );
    }

    // -----------------------------------------------------------------
    // 3. Call Brevo
    // -----------------------------------------------------------------
    const brevoRes = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'api-key': BREVO_API_KEY,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sender: {
          name: BREVO_SENDER_NAME,
          email: BREVO_SENDER_EMAIL,
        },
        to: [{ email: to }],
        subject,
        htmlContent: html,
        textContent: text,
      }),
    });

    const brevoText = await brevoRes.text();

    if (!brevoRes.ok) {
      return json(
        { error: `Brevo error (${brevoRes.status}): ${brevoText}` },
        502,
      );
    }

    return json({ ok: true, messageId: safeParse(brevoText)?.messageId });
  } catch (e) {
    return json({ error: `Unexpected: ${e}` }, 500);
  }
});

function safeParse(s: string): Record<string, unknown> | null {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}