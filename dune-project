(lang dune 3.17)

(name display)

(generate_opam_files true)

(source
 (github mtelvers/pzem))

(authors "Mark Elvers <mark.elvers@tunbury.org>")

(maintainers "Mark Elvers <mark.elvers@tunbury.org>")

(license MIT)

(documentation https://github.com/mtelvers/pzem)

(package
 (name display)
 (synopsis "PZEM power monitor")
 (description "This project uses the PZEM-004T to monitor mains power usage using a Raspberry PI. Voltage, current and power usage are displayed on an SSD1306 I2C display.")
 (depends ocaml i2c))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
