#include <stdlib.h>
#include <math.h>
void step_1(
    const size_t p_size_0,
    const size_t p_size_1,
    const size_t rho_size_1,
    const size_t prev_rho_size_1,
    const double_t **prev_rho_values,
    const double_t **rho_values,
    const double_t **z_values,
    double_t **p_values) {
    size_t i, j;
    double_t *tmp = malloc(sizeof(double_t[p_size_1]));
    for (j = 0; j < p_size_1; ++j)
        tmp[j] = rho_values[j / rho_size_1][j % rho_size_1] /
            prev_rho_values[j / prev_rho_size_1][j % prev_rho_size_1];
#pragma scop
    for (i = 0; i < p_size_0; ++i)
        for (j = 0; j < p_size_1; ++j)
            p_values[i][j] = z_values[i][j] + tmp[j] * p_values[i][j];
#pragma endscop
    free(tmp);
}
