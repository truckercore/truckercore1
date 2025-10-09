# policy/opa/ai_explainability.rego
package truckercore.ai

deny["AI response missing rationale"] {
  not input.sample_response.rationale
}
