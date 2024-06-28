#include <stdlib.h>
#include <math.h>
void step_2(
    const size_t x_size_0,
    const size_t x_size_1,
    const double_t **p_values,
    const double_t **q_values,
    double_t **x_values,
    double_t **r_values) {
    size_t i, j;
    double_t *tmp = malloc(sizeof(double_t[x_size_1]));
#pragma scop
    for (i = 0; i < x_size_0; ++i) {
        for (j = 0; j < x_size_1; ++j) {
            x_values[i][j] += tmp[j] * p_values[i][j];
            r_values[i][j] -= tmp[j] * q_values[i][j];
        }
    }
#pragma endscop
    free(tmp);
}
