#include <stdlib.h>
#include <math.h>
void add_scaled_identity(
  const size_t mtx_stride,
  double_t **mtx_values,
  const size_t dim_0,
  const size_t dim_1,
  const double_t valpha,
  const double_t vbeta) {
  size_t row, col;
#pragma scop
  for (row = 0; row < dim_0; row++)
    for (col = 0; col < dim_1; col++) {
      mtx_values[row][col] *= vbeta;
      if (row == col) mtx_values[row][row] += valpha;
    }
#pragma endscop
}
