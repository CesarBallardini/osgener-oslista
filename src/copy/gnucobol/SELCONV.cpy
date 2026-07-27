      *----------------------------------------------------------------
      * SELCONV (GNUCOBOL DIALECT) - CONV TABLE FILE SELECTION.
      * DYNAMIC IS REQUIRED HERE: UNDER -STD=MVS A BARE IDENTIFIER
      * IN ASSIGN IS TAKEN AS AN ASSIGNMENT-NAME LITERAL ('DDNAME'),
      * NOT AS A VARIABLE HOLDING THE FILE NAME.
      *----------------------------------------------------------------
           SELECT OPTIONAL CONVTAB-F ASSIGN TO DYNAMIC WS-CONV-DDNAME
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-CNV.
