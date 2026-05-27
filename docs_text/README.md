Place pre-extracted plain text versions of the PDS PDFs in this folder for
trial-account Snowflake Cortex Search setups.

Expected files for the current repo:

- `vusa.txt`
- `vwrp.txt`

The SQL setup script indexes these `.txt` files instead of parsing the PDFs in
Snowflake because trial accounts do not support the PDF parsing functions used
by non-trial accounts.
