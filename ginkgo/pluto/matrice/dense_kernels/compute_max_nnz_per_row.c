#include <stdlib.h>
void compute_max_nnz_per_row(
  const size_t source_size_0,
  const size_t source_size_1,
  const size_t source_stride,
  const size_t source_values) {
  size_t i, j, result = 0, num_nonzeros;
#pragma scop
  for (i = 0; i < source_size_0; ++i) {
    num_nonzeros = 0;
    for (j = 0; j < source_size_1; ++j)
      num_nonzeros += is_nonzero(source_values[i][j]);
    result = my_max(num_nonzeros, result);
  }
#pragma endscop
}
