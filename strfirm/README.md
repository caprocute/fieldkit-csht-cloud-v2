# Pre-Alpha Software Warning

This repository is in its very early stages. It has been used to generate some
JSON files for localization but is hardly ready to service the needs of the
broader community. Help is very welcome, though!

# What is this?

This is a simple CLI tool that scans a directory of sources files (right now
C/C++ projects) for tokens matching a regular expression and then generates a
series of files based on that scan:

- A single header file `l10n.h` that contains preprocessor `#define`'s for each
  of the matching tokens, assigning them a unique integer index.
- A `.c` file for each configured locale with a table of strings, indexed by
  those preprocessor defines.
- A `.json` file for each configured locale containing the translated string,
  adding any new tokens found in the scan and merging with the existing `.json`
file.

# Feature Ideas

- [ ] Configuration (file or CLI) of locales, token regex, etc...
