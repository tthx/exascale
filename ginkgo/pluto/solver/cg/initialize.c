void initialize(
  const size_t b_size_0,
  const size_t b_size_1,
  const double_t **b_values,
  double_t **r_values,
  double_t **z_values,
  double_t **p_values,
  double_t **q_values) {
  size_t i, j;
#pragma scop
  for (i = 0; i < b_size_0; ++i)
    for (j = 0; j < b_size_1; ++j) {
      r_values[i][j] = b_values[i][j];
      z_values[i][j] = 0;
      p_values[i][j] = 0;
      q_values[i][j] = 0;
    }
#pragma endscop
}
