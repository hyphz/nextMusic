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



Tempo                   db 7                              ; Number of frames per beat count

music                   db 0, 0
                        dw pattern_arp
                       ; db 0, 1
                       ; dw pattern_bass
                        db 12, 2
                        dw pattern_mel
                        db 1, 4
                        dw pattern_mel
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


failWaltz               db 0, 48, 4, 53, 8, 48, 4, 53, 8, $80


pattern_bass            db 0, 12, 4, 17, 4, 19, 4, $80



pattern_arp             db 0, 12, 1, 16, 1, 19, 1, 24
                        db 1, 17, 1, 21, 1, 24, 1, 29
                        db 1, 19, 1, 23, 1, 26, 1, 31
                        db 1, $80

pattern_mel             db 0, $82: dw BasicInstrument
                        db 0, 52
                        db 3, 48
                        db 1, 48
                        db 3, 50
                        db 1, 50
                        db 0, $82: dw SawInstrument
                        db 2, 52, 1, 53, 1, 52, 3, 48, 1, 48, 3, 45, 1, 43, 4, $80

