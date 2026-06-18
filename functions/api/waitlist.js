// Cloudflare Pages Function — POST /api/waitlist
// Stores a waitlist email in the D1 database bound as `DB`
// (see wrangler.toml). Same-origin only, so no CORS needed.

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

export async function onRequestPost({ request, env }) {
  let email = "";
  try {
    const ct = request.headers.get("content-type") || "";
    if (ct.includes("application/json")) {
      email = String((await request.json()).email || "");
    } else {
      email = String((await request.formData()).get("email") || "");
    }
  } catch {
    return json({ ok: false, error: "Couldn't read your submission." }, 400);
  }

  email = email.trim().toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 254) {
    return json({ ok: false, error: "Please enter a valid email address." }, 400);
  }

  if (!env.DB) {
    return json({ ok: false, error: "The waitlist is temporarily unavailable." }, 503);
  }

  try {
    const ua = (request.headers.get("user-agent") || "").slice(0, 300);
    // ON CONFLICT keeps it idempotent — re-submitting the same email is a no-op.
    await env.DB.prepare(
      "INSERT INTO waitlist (email, source, user_agent) VALUES (?, 'landing', ?) ON CONFLICT(email) DO NOTHING"
    )
      .bind(email, ua)
      .run();
    return json({ ok: true });
  } catch {
    return json({ ok: false, error: "Something went wrong — please try again." }, 500);
  }
}
