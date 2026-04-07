package truckercore.promoctl

deny["auto-promotion without blackout window"] {
  some i
  input.auto_promote_cfg[i].enabled == true
  not input.auto_promote_cfg[i].blackout_defined
}
