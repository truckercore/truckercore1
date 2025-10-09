package truckercore.market

deny["row violates k-anonymity (<10)"] {
  some i
  input.rows[i].n < 10
}
