Deno.serve(async () => {
  // Skeleton retrain trigger: integrate your ML pipeline/orchestrator here.
  // On success, update ai_feature_summaries rows with kind='train' for the latest model_version.
  return new Response("ok");
});
