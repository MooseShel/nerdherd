import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const ADMIN_EMAIL = "Hussein.shel@outlook.com";

serve(async (req) => {
  try {
    const { type, payload } = await req.json();

    if (type === "tutor_verification") {
      const { user_id, full_name, verification_doc_url } = payload;
      
      console.log(`Sending verification email for ${full_name} (${user_id})`);

      if (RESEND_API_KEY) {
        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${RESEND_API_KEY}`,
          },
          body: JSON.stringify({
            from: "Nerd Herd App <onboarding@resend.dev>", // Default testing domain
            to: [ADMIN_EMAIL],
            subject: `New Tutor Verification: ${full_name}`,
            html: `
              <h1>New Tutor Verification Submitted</h1>
              <p><strong>User:</strong> ${full_name}</p>
              <p><strong>User ID:</strong> ${user_id}</p>
              <p><strong>Document:</strong> <a href="${verification_doc_url}">View Document</a></p>
              <p>Please review explicitly in the Admin Dashboard.</p>
            `,
          }),
        });

        const data = await res.json();
        return new Response(JSON.stringify(data), {
          headers: { "Content-Type": "application/json" },
        });
      } else {
        console.log("No RESEND_API_KEY configured. Logging email intention.");
        return new Response(JSON.stringify({ message: "Email logged (No API Key)" }), {
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    return new Response(JSON.stringify({ message: "Unknown type" }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
