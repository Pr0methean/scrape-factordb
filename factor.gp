tryfactor(x:int) = {
  my(flag = if (x > 10^91, 9, 0));
  my(factors = factorint(x, flag));
  my(len = #(factors[, 2]));
  if (factors[len, 2] == 1, factors[1..(len - 1), 1], factors[,1])
}
