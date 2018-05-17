# general
- documentation
  - some markdown pages with explanations?
- makefile
  - add install target?
    - install vim-dir (in vim: add to runtimepath)
    - install syntax-db (somewhere)
    - install package
    - install bin
    - ...?

# lib
- regfile support
  - add get\_regfile -name (without -of option) possibility
- add cleanup function to reset library (with proper freeing of db...)
- add net/signal data type to retrieve signals?

# tcllib
- "-help"-switches for main commands

# templates
- integrate regfile into default template
- import namespace functions of aux,preprocess,... into template run namespace?

# bin
- import construction namespace procs before sourcing construction scripts?
- allow multiple construction scripts?
- run construction script in encapsulated namespace
- add "nowriteout" function or similar? -> allows for construction with intermediate clean, depends on cleanup function

# vim
- decide on one template-syntax file
- export syntax-db into vim dir?
