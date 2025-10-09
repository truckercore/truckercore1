package truckercore.roi

deny["AI response missing rationale"] {
  not input.sample_ai_response.rationale
}
