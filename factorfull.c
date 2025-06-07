/*-*- compile-command: "/usr/lib/llvm-20/bin/clang -o ff factorfull.c -O3 -flto -Wall -fno-strict-aliasing -O3 -march=native -fPIC -Wl,-rpath,/usr/local/lib -lc -lm -L/usr/local/lib -I\"/usr/local/include\" -lpari"; -*-*/
#include <stdio.h>
#include <string.h>
#include <pari/pari.h>
/*
GP;install("tryfactor","G","tryfactor","./factor.gp.so");
*/
void tryfactor(char *);
/*End of prototype*/

void
tryfactor(char *input)
{
  // long l1 = 0;
  GEN x = gp_read_str(input);
  GEN p2 = gen_0;
  if (typ(x) != t_INT)
    pari_err_TYPE("tryfactor",x);
  GEN factor_iter = ifac_start(x, 0);
  long e, e1;
  GEN last_cofactor = gen_0;
  while (ifac_next(&factor_iter, &p2, &e) != 0) {
    if (!equalii(p2, last_cofactor)) {
      pari_printf("%Ps\n", p2);
      fflush(stdout);
    }
    ifac_read(factor_iter, &last_cofactor, &e1);
    if (e1 > 1) {
      last_cofactor = gen_0;
    }
  }
}

int main(int argc, char **argv) {
  pari_init_opts(1000 * 1000 * 1000, 2, INIT_noIMTm | INIT_noINTGMPm | INIT_DFTm);
  tryfactor(argv[1]);
  // pari_close();
}

