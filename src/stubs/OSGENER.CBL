      *================================================================
      * OSGENER STUB - DISPATCHES INTO THE UNIFIED OSENGINE (D0.4/D0.5)
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. OSGENER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-MODE   PIC X(7) VALUE "OSGENER".
       PROCEDURE DIVISION.
           CALL "OSENGINE" USING WS-MODE END-CALL
           STOP RUN.
