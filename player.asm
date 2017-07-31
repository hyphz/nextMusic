; Attempt at a SD/AY driver
; By Mark Green (hyphz)
; Licensed under Creative Commons Attribution 4.0

; Thanks:
; utz@SpecNext
; Matt Westcott
; Leeda Kifee
; Cesar Hernandez Bano for Zesarux

AppFilename             equ "player"                   ; What we're called (for file generation)

AppFirst                equ $8000                       ; First byte of code (uncontended memory)

                        zeusemulate "128K","ULA+"       ; Set the model and enable ULA+

AyRegSelect             equ $fffd
AyRegWrite              equ $bffd
KempstonJoystick        equ 31

AyCoarseTuneA           equ 1
AyFineTuneA             equ 0
AyCoarseTuneB           equ 3
AyFineTuneB             equ 2
AyCoarseTuneC           equ 5
AyFineTuneC             equ 4
AyAmplitudeA            equ 8
AyAmplitudeB            equ 9
AyAmplitudeC            equ 10
AyAmpPeriodFine         equ 11
AyAmpPeriodCoarse       equ 12
AyAmpShape              equ 13

NumVoices               equ 16

out16bc                 macro(port, val)            ; Outputs on 16 bit port address
                        ld bc, port
                        out (c), val
                        mend

in16bca                 macro(port)                 ; Inputs to A from 16 bit port address
                        ld bc, port
                        in a,(c)
                        mend

aysendabc               macro(reg, val)             ; Sends val to AY register reg
                        ld a, reg
                        ld bc, AyRegSelect
                        out (c), a
                        ld b, $bf                   ; C is the same, $fd
                        ld a, val
                        out (c), a
                        mend

                        struct
UpdateStatus            ds 1
PatternPC               ds 2
LoopPC                  ds 2
BeatCountdown           ds 1
Stage                   ds 1
StageCounter            ds 2
VoiceSize               equ .
                        send


; Start planting code here. (When generating a tape file we start saving from here)

                        org AppFirst                    ; Start of application

AppEntry                call MusicInit
TestLoop                call MusicUpdate
                        halt
                        jp TestLoop


MusicInit               aysendabc(7, 56)
                        aysendabc(AyAmplitudeA, %00010000)
                        aysendabc(AyAmplitudeB, %00010000)
                        aysendabc(AyAmplitudeC, %00010000)
                        aysendabc(AyAmpPeriodFine, $01)
                        aysendabc(AyAmpPeriodCoarse, $10)
                        aysendabc(AyAmpShape, %00001000)
                        ld bc, music                      ; Set musicPointer to address of start of music
                        ld (MusicMasterPC), bc
                        ld a, 0                           ; Set initial tempoWait to 0 so music starts immediately
                        ld (TempoWait), a
                        ret


MusicUpdate             ld a, (TempoWait)                 ; Are we waiting for a beat? Load temp value
                        sub 1                             ; Subtract one from it
                                                          ; (SUB takes 3 more states than DEC but sets the carry flag properly,
                                                          ; which saves us from doing a CP to test for zero, which would take 7 more)
                        jp c, NextBeat                    ; If subtracting 1 overflowed, it was 0, so go process the beat
                        ld (TempoWait), a                 ; It didn't overflow. Store it back into TempoWait counter
                        ld hl, VoiceStatusBank            ; No beat this frame. But any voices need frame-based maintenance?
                        ld b, NumVoices                   ; HL is address of voice to check, B is loop counter for checking
CheckVFrameMaint        ld a, (hl)                        ; Load status byte for current voice
                        bit 1,a                           ; Is bit 1 set?
                        jp nz, NoFrameMaintenance         ; No, no frame maintenance needed
                        push hl
                        push bc
                        ; call FrameMaintainVoice         ; Yes, go do it (we don't know how yet ;) )
                        pop bc
                        pop hl
NoFrameMaintenance      ld de, VoiceSize
                        add hl, de                        ; Move IX to point at next voice block
                        djnz CheckVFrameMaint             ; Decrement B and loop if not zero
                        ret                               ; We're done


NextBeat                ld a, (Tempo)                     ; Beat has happened. Reset tempo clock
                        ld (TempoWait), a
                        ld a, (BeatWait)                  ; Check beat clock for master commands
                        sub 1                             ; Same trick as above to set carry
                        jp nc, NoMasterCmd                ; If it didn't overflow it wasn't 0, we are waiting, don't run master command
                        call NextMasterCmd                ; Yes, We aren't waiting -> go run it
                                                          ; Back from doing master command, set delay for next master command
                        ld hl,(MusicMasterPC)             ; HL holds address of delay for next command
                        ld a,(hl)                         ; A holds delay for next command
                        ld (BeatWait), a                  ; Load it into wait
                        jp MasterCmdDone                  ; Skip timer stuff below

NoMasterCmd             ld (BeatWait), a                  ; Put subtracted, non-overflowed, value back into beat clock
MasterCmdDone           ld hl, VoiceStatusBank            ; Now do beat AND frame maintenance.
                        ld b, NumVoices                   ; B is loop counter for checking
CheckBeatMaint          ld a, (hl)                        ; Load status byte for current voice
                        bit 0,a                           ; Is bit 0 set?
                        jp z, NextVoiceBeatMaint          ; If not, Nothing needed (nothing would ever need frame but not beat maintenance)
                        bit 1,a                           ; Is bit 1 set?
                        jp z, JustBeatMaintenance         ; If not, Only beat maintenance needed
                        push bc                           ;
                        push hl
                        ; call FrameMaintainVoice         ; Yes, go do it (we don't know how yet.. ;) )
                        call BeatMaintainVoice
                        pop hl
                        pop bc
                        jp NextVoiceBeatMaint             ; Done with this voice
JustBeatMaintenance     push bc                           ; Do only beat maintenance
                        push hl
                        call BeatMaintainVoice
                        pop hl
                        pop bc
NextVoiceBeatMaint      ld de, VoiceSize
                        add hl, de
                        djnz CheckBeatMaint
                        ret                               ; We're done


NextMasterCmd           ld ix, (MusicMasterPC)            ; IX is current delta time
                        ld d, (ix+1)                      ; This will be command
                        ld a, d                           ; Mask off voice number
                        and %11110000
                        jp z, StartPatternCmd             ; Check command. 0 = Start pattern
                        ret

StartPatternCmd         ld a, d                           ; Double voice number to get index into address list
                        add a, a
                        ld l, a
                        ld h, VoiceStatusSeg
                        ld c, (hl)
                        inc hl
                        ld b, (hl)
                        ld iy, bc
                        ld a, (iy+UpdateStatus)           ; Get voice status byte
                        set 0, a                          ; It needs beat maintenance now.
                        ld (iy+UpdateStatus), a           ; Store that fact in voice status byte
                        ld hl, (ix+2)                     ; Load up 2 bytes of pattern address into voice status table
                        ld (iy+PatternPC), hl
                        ld (iy+LoopPC), hl
                        ld bc, (iy+PatternPC)             ; BC is address of first byte of the pattern
                        ld a,(bc)                         ; A is first byte of the pattern, which will be the initial deltatime
                        ld (iy+BeatCountdown), a          ; Set initial beat countdown to this
                        ld bc, 4                          ; Move master PC on by 4 bytes
                        add ix, bc
                        ld (MusicMasterPC), ix            ; And store back into master PC
                        ret

; BeatMaintainVoice. Called with HL pointing to voice's control block and B holding reversed voice number
BeatMaintainVoice       ld a, NumVoices                   ; Put real voice number into D
                        sub b
                        ld d, a
                        ld a, l                           ; BLEAUGH
                        ld ixl, a
                        ld a, h
                        ld ixh, a
                        ld a,(ix+BeatCountdown)           ; Time for next pattern command?
                        cp 0
                        jp z, PatternCommand              ; Yes, go do it
                        dec a                             ; Nope, just update beat countdown
                        ld (ix+BeatCountdown), a
                        ret                               ; And we're done
PatternCommand          ld bc,(ix+PatternPC)              ; BC is address of current pattern deltatime
                        ld iy, bc                         ; Move to IY to use indexing
                        inc iy                            ; Now points to base of command
                        ld a,(iy+0)                       ; Get command value
                        bit 7, a                          ; Is MSB set?
                        jp nz, runNoteCommand             ; It's a command, not a note
                        ld h, notetableSeg                ; It's a note. Get segment address of note table
                        add a,a                           ; Notes are 2 bytes, double to get offset in note table
                        ld l,a                            ; Note table is segment aligned so just setting low bit finds location
                        ld a,d                            ; AY fine tune register number is voice number * 2, get voice number
                        add a,a
                        ld e,a                            ; E is fine tune register number
                        aysendabc(e,(hl))                 ; Get and send fine tune value from note table
                        inc hl                            ; Go to next byte in note table
                        inc e
                        aysendabc(e,(hl))                 ; Get and send coarse tune value from note table
PatternPCOneByte        inc iy                            ; IX now points to address of wait time of next command
                        ld bc, iy
                        ld (ix+PatternPC), bc             ; It's the new music PC
                        jp FinishPatternCommand

runNoteCommand          and %01111111                     ; Mask off command indicator bit
                        jp z, PatternLoopCommand          ; Command 0, loop
                        jp PatternPCOneByte               ; Invalid command, skip it

PatternLoopCommand      ld bc, (ix+LoopPC)                ; Set patternPC to loopPC
                        ld (ix+PatternPC), bc
                        jp FinishPatternCommand           ; Since we just changed patternPC don't calculate it for "next" command

FinishPatternCommand    ld bc,(ix+PatternPC)              ; Get wait value for next command
                        ld a,(bc)
                        ld (ix+BeatCountdown),a
                        cp 0
                        jp z, PatternCommand
                        ret

; ----------- Variables

                        align $0100

CurVoiceAddress = VoiceStatusBank
VoiceStatusLoc          loop NumVoices
                           dw CurVoiceAddress
                           CurVoiceAddress = CurVoiceAddress + VoiceSize
                        lend
VoiceStatusSeg          equ (VoiceStatusLoc >> 8)

TempoWait               db 0                ; Counter for frames left before a beat
BeatWait                db 00               ; Counter for beats left before master command
MusicMasterPC           dw 00               ; Address of current master command


VoiceStatusBank         loop NumVoices      ; Status structures for voices
                          loop VoiceSize
                            db 00
                          lend
                        lend

; 8 octaves, note indexes 0-95, from 128 documentation
                        align $0100

notetable               db 16, 13, 84, 12, 163, 11, 252, 10, 94, 10, 201, 9, 68, 9, 184, 8, 58, 8
                        db 196, 7, 85, 7, 235, 6, 136, 6, 42, 6, 209, 5, 126, 5, 47, 5, 228, 4, 158, 4
                        db 92, 4, 29, 4, 226, 3, 170, 3, 117, 3, 68, 3, 21, 3, 232, 2, 191, 2, 151, 2
                        db 114, 2, 79, 2, 46, 2, 14, 2, 241, 1, 213, 1, 186, 1, 162, 1, 138, 1, 116, 1
                        db 95, 1, 75, 1, 57, 1, 39, 1, 23, 1, 7, 1, 248, 0, 234, 0, 221, 0, 209, 0, 197, 0
                        db 186, 0, 175, 0, 165, 0, 156, 0, 147, 0, 139, 0, 131, 0, 124, 0, 117, 0, 110, 0
                        db 104, 0, 98, 0, 93, 0, 87, 0, 82, 0, 78, 0, 73, 0, 69, 0, 65, 0, 62, 0, 58, 0, 55, 0
                        db 52, 0, 49, 0, 46, 0, 43, 0, 41, 0, 39, 0, 36, 0, 34, 0, 32, 0, 31, 0, 29, 0, 27, 0
                        db 26, 0, 24, 0, 23, 0, 21, 0, 20, 0, 19, 0, 18, 0, 17, 0, 16, 0, 15, 0, 14, 0, 13, 0

notetableSeg            equ (notetable >> 8)



Tempo                   db 13                              ; Number of frames per beat count

music                   db 0, 0
                        dw pattern
                        db 2, 1
                        dw pattern
                        db 255


pattern                 db 0, 12, 1, 16, 1, 19, 1, 16, 1, %10000000




; Stop planting code after this. (When generating a tape file we save bytes below here)
AppLast                 equ *-1                         ; The last used byte's address

; Generate some useful debugging commands

                        profile AppFirst,AppLast-AppFirst+1     ; Enable profiling for all the code

; Setup the emulation registers, so Zeus can emulate this code correctly

Zeus_PC                 equ AppEntry                            ; Tell the emulator where to start
Zeus_SP                 equ $FF46                               ; Tell the emulator where to put the stack

; These generate some output files

                        ; Generate a SZX file
                        output_szx AppFilename+".szx",$0000,AppEntry    ; The szx file

                        ; If we want a fancy loader we need to load a loading screen
;                        import_bin AppFilename+".scr",$4000            ; Load a loading screen

                        ; Now, also generate a tzx file using the loader
                        output_tzx AppFilename+".tzx",AppFilename,"",AppFirst,AppLast-AppFirst,2,AppEntry ; A tzx file using the loader
                        output_tzx AppFilename+"m1.tzx",AppFilename,"",AppFirst,AppLast-AppFirst,1,AppEntry ; A tzx file using the loader


                        output_tap AppFilename+".tap",AppFilename,"",AppFirst,AppLast-AppFirst,3,AppEntry ; A tzx file using the loader



