//SCDJOB01 JOB (MIG),'RUN OSGENER',CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//* ===================================================================
//* OSGENER EXECUTION - UNIFIED SCD 1/84 ENGINE (OSENGINE + STUB)
//* PGM NAME <= 8 CHARS (D0.5). FOR OSLISTA: EXEC PGM=OSLISTA
//* THE SYSIN DECK MATCHES THE run_sim.sh SIMULATION (D0.7)
//* ===================================================================
//RUNSTEP  EXEC PGM=OSGENER
//SYSPRINT DD SYSOUT=*
//SYSLIST  DD SYSOUT=*
//SYSUT1   DD DSN=YOUR.DATASET.INPUT.SYSUT1,DISP=SHR
//SYSUT6   DD DSN=YOUR.DATASET.LOOKUP.SYSUT6,DISP=SHR
//SYSUT2   DD DSN=YOUR.DATASET.OUTPUT.SYSUT2,
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(10,5),RLSE),
//            DCB=(RECFM=FB,LRECL=150,BLKSIZE=0)
//SYSUT4   DD DSN=YOUR.DATASET.OUTPUT.SYSUT4,
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=150,BLKSIZE=0)
//SYSUT5   DD DSN=YOUR.DATASET.REJECTS.SYSUT5,
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=80,BLKSIZE=0)
//* -------------------------------------------------------------------
//* CONTROL CARDS (SYSIN)
//* -------------------------------------------------------------------
//SYSIN    DD *
PESQIN 1,5,1
RCIN  1,3,EQ,'ARG'/1,3,EQ,'BRA'
COND1 8,4,GE,'1990'
GENER 1,7/80,1/'0','1','2','3'
CODIG '1',OBL,'2'
INCON '0'/12,6,FD/13,1,ND
FIELD 1,3,MOVE,1
FIELD 18,6,MOVE,10
FIELD 98,6,MOVE,20
FIELD 18,6,zDVy,30
/*
//
