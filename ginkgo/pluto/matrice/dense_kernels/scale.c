#include <stdlib.h>
#include <math.h>
void scale(
  const size_t x_size_0,
  const size_t x_size_1,
  const size_t x_stride,
  const double_t *alpha_values,
  doulbe_t **x_values) {
  size_t i, j;
  if (alpha->get_size()[1] == 1) {
    const auto valpha = alpha_values[0];
#pragma scop
    for (i = 0; i < x_size_0; ++i)
      for (j = 0; j < x_size_1; ++j)
        x_values[i][j] *= valpha;
#pragma endscop
  } else {
#pragma scop
    for (i = 0; i < x_size_0; ++i)
      for (j = 0; j < x_size_1; ++j)
        x_values[i][j] *= alpha_values[j];
#pragma endscop
  }
}
