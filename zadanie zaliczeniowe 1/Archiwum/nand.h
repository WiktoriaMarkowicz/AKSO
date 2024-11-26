#ifndef NAND_H
#define NAND_H

#include <stdbool.h>
#include <stddef.h>
#include <sys/types.h>

typedef struct nand nand_t;

nand_t* nand_new(unsigned n);
void    nand_delete(nand_t *g);
int     nand_connect_nand(nand_t *g_out, nand_t *g_in, unsigned k);
int     nand_connect_signal(bool const *s, nand_t *g_in, unsigned k);
ssize_t nand_evaluate(nand_t **g, bool *s, size_t m);
ssize_t nand_fan_out(nand_t *g);

#endif
