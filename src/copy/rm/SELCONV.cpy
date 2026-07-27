      *----------------------------------------------------------------
      * SELCONV (RM/COBOL DIALECT) - CONV TABLE FILE SELECTION.
      * RM/COBOL TREATS AN IDENTIFIER IN ASSIGN AS A VARIABLE
      * HOLDING THE FILE NAME NATIVELY (GNUCOBOL -STD=RM MATCHES).
      *----------------------------------------------------------------
           SELECT OPTIONAL CONVTAB-F ASSIGN TO WS-CONV-DDNAME
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-CNV.
