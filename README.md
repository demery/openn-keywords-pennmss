# BiblioPhilly keywords for Penn Manuscripts

Scripts to generate OPenn folders and BiblioPhilly keywords.txt files from the
Penn MSS spreadsheet that used Penn in Hand facets as guides for keyword
generation.

One script, `just_keywords.rb`, parses `openn_keywords.csv` and generates
`folders_keywords.csv`. The other, `make_keywords_folders.rb`, takes
`folders_keywords.csv` as input and creates the folders and the `keywords.txt`
file for each.
