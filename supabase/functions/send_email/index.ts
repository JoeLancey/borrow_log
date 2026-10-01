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
    const SUPABASE_URL = Deno.env.get('761ccd514df341c8a244006a0c9a53cc0a2afe1b0dcb5e4801eef52a011a2a4f')!;
    const SERVICE_ROLE = Deno.env.get('6d7238f45220b136b5d990a62c313b2f734e16295ddffc7d9891e6c6b1d56488')!;
    const ANON_KEY = Deno.env.get('8aba34ddc1e2317411f16fcb94c12d758281a063bd069b0ed76aa1f2c7f1fc81')!;
    const BREVO_API_KEY = Deno.env.get(' 754c27b8aef5873beeee0f6ec67742022d7299077729ad5d553bb71dce859449');
    const BREVO_SENDER_EMAIL = Deno.env.get(' 080b87a72e4365ec7070cd333194048a4f56a451ebdc1723dea589f76a6a520a');
    const BREVO_SENDER_NAME = Deno.env.get('B0345f98693d39ace2f571eeed27fb6f98c6ea08cb42aa63e38043b3c5fcbe757') ?? 'BORROW LOG';

    if (!BREVO_API_KEY || !BREVO_SENDER_EMAIL) {
      return json({ error: 'Missing Brevo configuration' }, 500);
    }

    // -----------------------------------------------------------------
    // 1. Verify caller is staff (skipped if no Authorization header — for
    //    manual testing only; the Flutter client always sends the JWT)
    // -----------------------------------------------------------------
    const authHeader = req.headers.get('Authorization');

    if (authHeader) {
      const jwt = authHeader.replace('Bearer ', '');
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