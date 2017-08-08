BasicAmpCurve           db $05, 2
                        db $0f, 2
                        db $0c, 2
                        db $0c, 0

BasicRelease            db $0c,2
                        db $0c,2
                        db $0c,2
                        db $0c,2
                        db $0c,2
                        db $05,2
                        db $00,0

SawtoothMaybe           db $0c, 2
                        db $0e, 2
                        db $0f, -4

OneBeatCurve            db $05, 2
                        db $0f, 2
                        db $0c, 2
                        db $0c,2
                        db $0c,2
                        db $0c,2
                        db $05,0




BasicInstrument         dw BasicAmpCurve, BasicRelease, OneBeatCurve
SawInstrument           dw SawtoothMaybe, SawtoothMaybe, SawtoothMaybe



Tempo                   db 10                              ; Number of frames per beat count

music                   db 0, 0
                        dw soTopline
                        db 0, 1
                        dw soMidline
                        db 0, 2
                        dw soLowline
                        db 0, 4
                        dw altoline
                        db 0, 5
                        dw tenHiline
                        db 0, 6
                        dw tenLowline
                        db 0, 8
                        dw bassLine
                        db 0, 9
                        dw organPedal
                        db 0, 10
                        dw organTreble

                       ; db 0, 1
                       ; dw pattern_bass
;                        db 12, 2
;                        dw pattern_mel
;                        db 1, 4
;                        dw pattern_mel
                      ;  db 2, 1
                      ;  dw pattern
                        db 255



; c  c#  d  d#  e  f  f# g  g# a  a# b
; 0  1   2  3   4  5  6  7  8  9  10 11
; 12 13  14 15  16 17 18 19 20 21 22 23
; 24 25  26 27  28 29 30 31 32 33 34 35
; 36 37  38 39  40 41 42 43 44 45 46 47
; 48 49  50 51  52 53 54 55 56 57 58 59
; 60 61  62 63  64 65 66 67 68 69 70 71
; 72 73  74 75  76 77 78 79 80 81 82 83
; 84 85  86 87  88 89 90 91 92 93 94 95


organTreble  db 2
             db 38, 2
             db 40, 2
             db 40, 1
             db 42, 1
             db 43, 1
             db 45, 1
             db 47, 3
             db 45, 1
             db 48, 3
             db 45, 1
             db 47, 3
             db 43, 1
             db 42, 6
             db $83

organPedal   db 0
             db 26, 18
             db 33, 2
             db 26, 6
             db $83


bassLine     db 2
             db 50,2
             db 48,2
             db 47,2
             db 45,1
             db 47,1
             db 48,2
             db 50,2
             db 52,4
             db 48,2
             db 50,6
             db $83


tenHiline    db 2
             db 50,2
             db 52,2
             db 48,2
             db 52,1
             db 50,1
             db 52,2
             db 54,2
             db 55,4
             db 55,2
             db 54,6
             db $83


tenLowline   db 2
             db 50,2
             db 52,2
             db 52,2
             db 52,1
             db 50,1
             db 52,2
             db 54,2
             db 55,4
             db 55,2
             db 54,6
             db $83


altoline     db 2
             db 50,2
             db 55,2
             db 55,2
             db 60,3
             db 59,1
             db 57,1
             db 59,1
             db 60,4
             db 59,2
             db 57,6
             db $83


soLowline    db 2
             db 50,2
             db 55,2
             db 60,2
             db 64,3
             db 62,1
             db 60,1
             db 62,1
             db 64,4
             db 60,2
             db 62,6
             db $83


soIntro      db 2,50
             db 2,52
             db 2,55
             db 2,60
             db 3,59
             db 1,57
             db 1,57
             db 1,62
             db 4,57
             db 2,84
             db 2,$83

soTopline    db 2
             db 50,2
             db 55,2
             db 60,2
             db 67,3
             db 66,1
             db 64,1
             db 66,1
             db 67,4
             db 64,2
             db 69,6
             db $83

soMidline    db 2
             db 50,2
             db 55,2
             db 60,2
             db 67,3
             db 66,1
             db 64,1
             db 66,1
             db 67,4
             db 64,2
             db 66,6
             db $83



