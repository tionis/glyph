  :name "glyph"
(declare-project
  :description "a personal data manager for the command line"
  :dependencies  ["https://github.com/janet-lang/spork"
                  "https://tasadar.net/tionis/jeff.git"
                  "https://git.sr.ht/~pepe/jfzy" # TODO this can probably be removed, but is still required by jff as a transitive dependency
                  "https://github.com/tionis/remarkable" # TODO this needs tags support
                  "https://tasadar.net/tionis/chronos" # TODO this needs various fixes and API changes
                  ])

(declare-source :source ["glyph"])

(declare-executable
  :name "glyph"
  #:lflags ["-static"] # disable due to compile errors on platforms like termux on ARM
  :entry "glyph/cli.janet"
  :install true)

(declare-native
  :name "_uri"
  :source ["src/uri.c"])
