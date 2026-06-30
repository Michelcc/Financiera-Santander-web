import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { documento, asesor_id, consentimiento } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const lastDigit = parseInt(documento?.slice(-1) ?? "5", 10);
    let calificacion = "Normal";
    let deuda = 0;
    let mora = 0;

    if (documento?.endsWith("999")) {
      calificacion = "Perdida";
      deuda = 15200;
      mora = 180;
    } else if (lastDigit === 3) {
      calificacion = "CPP";
      deuda = 2500;
      mora = 15;
    } else if (lastDigit === 7) {
      calificacion = "Deficiente";
      deuda = 8900;
      mora = 45;
    }

    const result = {
      calificacion_sbs: calificacion,
      entidades_con_deuda: deuda > 0 ? 2 : 0,
      deuda_total_pen: deuda,
      mayor_deuda: deuda > 0 ? deuda * 0.65 : 0,
      dias_mayor_mora: mora,
    };

    if (asesor_id) {
      await supabase.from("consultas_buro").insert({
        asesor_id,
        documento,
        calificacion_sbs: calificacion,
        entidades_con_deuda: result.entidades_con_deuda,
        deuda_total_pen: deuda,
        mayor_deuda: result.mayor_deuda,
        dias_mayor_mora: mora,
        consentimiento_firmado: consentimiento ?? true,
      });
    }

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
