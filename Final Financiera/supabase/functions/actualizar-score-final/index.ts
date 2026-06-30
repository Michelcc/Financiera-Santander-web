import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const { record } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const scoreFinal =
      (record.score_transaccional ?? 0) + (record.score_campo ?? 0);
    const hipotesis = scoreFinal * 100;
    const segmento =
      scoreFinal >= 700
        ? "PREMIER"
        : scoreFinal > 400
          ? "ESTANDAR"
          : "BASICO";

    const { error } = await supabase
      .from("clientes")
      .update({
        score_final: scoreFinal,
        hipotesis_credito: hipotesis,
        segmento,
      })
      .eq("id", record.id);

    if (error) throw error;

    return new Response(
      JSON.stringify({ score_final: scoreFinal, hipotesis_credito: hipotesis, segmento }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
