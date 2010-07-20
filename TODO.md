Bugs
----

- truncate_text should be unicode-aware (i.e. don't chop up UTF-8 sequences, don't
  separate combining characters)
- truncate_text should use punctuation not surrounded by whitespace as weak
  splitting points (cf. wbrize)


Features
--------

- JavaScript helper which implements the expanding behaviour
