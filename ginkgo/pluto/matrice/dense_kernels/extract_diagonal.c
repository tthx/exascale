#include <math.h>
#include <stdlib.h>
void extract_diagonal(
  const size_t diag_size,
  const double_t **orig_values,
  double_t *diag_values) {
  size_t i;
#pragma scop
  for (i = 0; i < diag_size; ++i)
    diag_values[i] = orig_values[i][i];
#pragma endscop
}
