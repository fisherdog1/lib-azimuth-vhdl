# Address Math Package
Utilities for common addressing calculations.

### bits_required(unsigned_max : natural)
Calculate the number of bits required to store unsigned integers up to and including unsigned_max. This is *not* the number of bits required to store unsigned_max *different values*. I.e. bits_required(256) is 9 while bits_required(255) is 8.
