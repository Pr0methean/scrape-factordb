/*-*- compile-command: "/usr/lib/llvm-20/bin/clang -o factor factor.c -O3 -flto -Wall -fno-strict-aliasing -O3 -march=native -fPIC -Wl,-rpath,/usr/local/lib -lc -lm -L/usr/local/lib -I\"/usr/local/include\" -lpari"; -*-*/
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <pari/pari.h>
/*
GP;install("tryfactor","G","tryfactor","./factor.gp.so");
*/
void tryfactor(char *);
/*End of prototype*/

const int MAX_SECONDS_FOR_ADDITIONAL_FACTOR = 10;

void
tryfactor(char *input)
{
  // long l1 = 0;
  GEN x = gp_read_str(input);
  GEN p2 = gen_0;
  if (typ(x) != t_INT)
    pari_err_TYPE("tryfactor",x);
/*
  if (strlen(input) >= 92)
    l1 = 11; // Skip slow methods (ECM,SIQS) for very large numbers, but still use fast methods (Pollard's rho, SQUFOF, trial factoring)
  else
    l1 = 0;
  factors = factorint(x, l1);
*/
  if (strlen(input) >= 83) {
    long e, e1;
    GEN last_cofactor = gen_0;
    GEN factor_iter = ifac_start(x, 1);
    while (ifac_next(&factor_iter, &p2, &e) != 0) {
      if (equalii(p2, last_cofactor) != 0) {
        return;
      }
      pari_printf("%Ps\n", p2);
      fflush(stdout);
      alarm(MAX_SECONDS_FOR_ADDITIONAL_FACTOR);
      ifac_read(factor_iter, &last_cofactor, &e1);
      if (e1 > 1) {
        last_cofactor = gen_0;
      }
    }
  } else {
    GEN factors = Z_factor(x);
    GEN len = stoi(glength(gel(factors, 2)));
    if (gequal1(gcoeff(factors, gtos(len), 2)))
      p2 = matslice0(factors, 1, gtos(gsubgs(len, 1)), 1, LONG_MAX);
    else
      p2 = gel(factors, 1);
    pari_printf("%Ps\n", p2);
  }
}

int main(int argc, char **argv) {
  pari_init_opts(1000 * 1000 * 1000, 2, INIT_noIMTm | INIT_noINTGMPm | INIT_DFTm);
  tryfactor(argv[1]);
  // pari_close();
}

