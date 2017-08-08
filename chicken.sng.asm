
BasicAmpCurve           db $05, 2
                        db $0f, 2
                        db $0c, 2
                        db $0c, 0

BasicRelease            db $0c,2
                        db $0c,2
                        db $05,2
                        db $05,0

NoRelease               db $0c,0



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


include "notedefs.asm"


BasicInstrument         dw BasicAmpCurve, BasicRelease, OneBeatCurve
SawInstrument           dw SawtoothMaybe, SawtoothMaybe, SawtoothMaybe
NoRelSlide              dw BasicAmpCurve, NoRelease, NoRelease
NoRelEnd                dw NoRelease, BasicRelease, BasicRelease

Tempo                   db 4                              ; Number of frames per beat count

music                   db 0, 0
                        dw CArp
                        db 12, 1
                        dw VerseBase
                        db 20, 0
                        dw DArp
                        db 16, 0
                        dw GArp
                        db 16, 0
                        dw CArp     ; Let verse repeat
                        db 32, 0
                        dw DArp
                        db 16, 0
                        dw GArp
                        db 16, 0
                        dw CArp
                        db 12, 1
                        dw BridgeBase  ; Change melody on half beat
                        db 4, 0
                        dw C7Arp     ; Change backing on barline
                        db 16, 0
                        dw FArp
                        db 16, 0
                        dw DArp
                        db 16, 0
                        dw GArp
                        db 255


GArp                    db 0
                        db _g1,2
                        db _d2,2
                        db _g2,2
                        db _d2,2
                        db $80

CArp                    db 0
                        db _c2,2
                        db _g2,2
                        db _c3,2
                        db _g2,2
                        db $80

C7Arp                   db 0
                        db _c2,2
                        db _g2,2
                        db _as2,2
                        db _g2,2
                        db $80


DArp                    db 0
                        db _d2,2
                        db _a2,2
                        db _d3,2
                        db _a2,2
                        db $80

FArp                    db 0
                        db _f1,2
                        db _c2,2
                        db _f2,2
                        db _c2,2
                        db $80

VerseBase               db 0         ; Actually starts on off beat, but this allows looping
                        db $82:dw NoRelSlide:db 0
                        db _e4,2     ; It's
                        db _d4,2     ; That
                        db _e4,2     ; Time
                        db _d4,4     ; Of
                        db _c4,4     ; Year
                        db _rest, 2   ; ()
                        db _d4,2     ; Now
                        db _e4,2     ; That
                        db _e4,2     ; Spring
                        db _f4,2     ; Is
                        db _f4,2     ; In
                        db _e4,2     ; The
                        db _d4,4     ; Air
                        db _rest,2
                        db _f4,2     ; When
                        db _e4,2     ; Those
                        db _d4,2     ; Three
                        db _d4,2     ; Wet
                        db _rest,2
                        db _d4,2     ; Gits
                        db _rest,2
                        db _c4,2     ; With
                        db _d4,2     ; Their
                        db _e4,2     ; Girl
                        db _e4,2     ; y
                        db _e4,2     ; Curl
                        db _d4,2     ; Ly
                        db _c4,2     ; Hair
                        db _rest,2   ; End on half-beat
                        db $80

BridgeBase              db 0         ; Should also start on half beat
                        db _e4,2     ; From
                        db _f4,2     ; The
                        db _g4,2     ; Shores
                        db _f4,4     ; Of
                        db _e4,4     ; Sprain
                        db _rest,2
                        db _f4,2     ; To
                        db _g4,2     ; The
                        db _a4,2     ; Coast
                        db _a4,2     ; Of
                        db _a4,2     ; South
                        db _g4,2     ; Ern
                        db _f4,2     ; France
                        db _d4,2     ; No
                        db _fs4,2    ; Mat
                        db _g4,2     ; Ter
                        db _a4,2     ; Where
                        db _g4,4     ; You
                        db _fs4,4    ; Hide
                        db _rest,2
                        db _g4,2     ; You
                        db _a4,2     ; Just
                        db _b4,2     ; Can't
                        db _b4,2     ; Es
                        db _b4,2     ; Cape
                        db _a4,2     ; This
                        db _g4,4     ; Dance
                        db $83

