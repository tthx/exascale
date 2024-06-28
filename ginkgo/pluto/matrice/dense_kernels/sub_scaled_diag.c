#include <math.h>
#include <stdlib.h>
void sub_scaled_diag(
  const size_t x_size_0,
  const size_t y_stride,
  const double_t *x_values,
  double_t **y_values,
  const double_t valpha) {
  size_t i;
#pragma scop
  for (i = 0; i < x_size_0; ++i)
     y_values[i][i] -= valpha * x_values[i];
#pragma endscop
}
