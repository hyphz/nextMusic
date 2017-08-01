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
SetBorder               equ $229b
PrintBC                 equ $1a1b
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
TestLoop                ld a, 01
                        call SetBorder
                        call MusicUpdate
                        ld a, 02
                        call SetBorder
                        halt
                        jp TestLoop


MusicInit               aysendabc(7, 56)
                        aysendabc(AyAmplitudeA, %00010000)
                        aysendabc(AyAmplitudeB, %00010000)
                        aysendabc(AyAmplitudeC, %00010000)
                        aysendabc(AyAmpPeriodFine, $01)
                        aysendabc(AyAmpPeriodCoarse, $10)
                        aysendabc(AyAmpShape, %00001000)
                        ld hl, music                      ; Set musicPointer to address of start of music
                        ld (MusicMasterPC), hl
                        ld a, 0                           ; Set initial tempoWait to 0 so music starts immediately
                        ld (TempoWait), a
                        ret


; -- See if there's a beat this frame or not
MusicUpdate             ld a, (TempoWait)                 ; Load tempo counter
                        sub 1                             ; Subtract one from it
                                                          ; (SUB takes 3 more states than DEC but sets the carry flag properly,
                                                          ; which saves us from doing a CP to test for zero, which would take 7 more)
                        jp c, NextBeat                    ; If subtracting 1 overflowed, it was 0, so go process the beat
                        ld (TempoWait), a                 ; It didn't overflow. Store it back into TempoWait counter
                                                          ; -- No beat this frame. Do frame maintenance
                        ld hl, VoiceStatusBank            ; HL is address of voice to check {
                        ld b, NumVoices                   ;     B is loop counter for checking {
CheckVFrameMaint        ld a, (hl)                        ;         Load status byte for current voice
                        bit 1,a                           ;         Is bit 1 set?
                        jp nz, NoFrameMaintenance         ;         No, this voice doesn't need frame maintenance
                        push hl                           ;         Save HL and BC (can't just save B, stack values have to be 16bit)
                        push bc
                        ; call FrameMaintainVoice         ;         Do frame maintenance (we don't know how yet ;) )
                        pop bc                            ;         Restore HL and BC
                        pop hl
NoFrameMaintenance      ld de, VoiceSize                  ;         DE is distance to move HL ahead to next voice
                        add hl, de                        ;         Move HL to point at next voice block
                        djnz CheckVFrameMaint             ;         Decrement B and loop if not zero
                                                          ;     }
                                                          ; }
                        ret                               ; We're done


; -- This frame is a beat. Update tempo clock
NextBeat                ld a, (Tempo)                     ; Load static tempo value
                        ld (TempoWait), a                 ; And resit tempo clock to it
                                                          ; -- Check if a master command is running this beat
                        ld a, (BeatWait)                  ; Load delta timer for master command
                        sub 1                             ; Same trick as above to set carry
                        jp nc, NoMasterCmd                ; If it didn't overflow it wasn't 0, we are waiting, don't run master command
                        call NextMasterCmd                ; Yes, We aren't waiting -> go run it
                                                          ; Back from doing master command, set delay for next master command
                        ld hl,(MusicMasterPC)             ; HL holds address of delay for next command
                        ld a,(hl)                         ; A holds delay for next command
NoMasterCmd             ld (BeatWait), a                  ; Put new delta wait (from command, or subtraction) back into delta timer
                                                          ; -- Do beat and frame maintenance on a beat frame
                        ld hl, VoiceStatusBank            ; HL is address of voice to check {
                        ld b, NumVoices                   ;     B is loop counter for checking {
CheckBeatMaint          ld a, (hl)                        ;         A is current voice's status byte {
                        bit 0,a                           ;             Is bit 0 set?
                        jp z, NextVoiceBeatMaint          ;             If not, Nothing needed (nothing would ever need frame but not beat maintenance)
                        bit 1,a                           ;             Is bit 1 set?
                        jp z, JustBeatMaintenance         ;             If not, Only beat maintenance needed
                                                          ;         }
                        push bc                           ;         Store HL and B
                        push hl                           ;
                        ; call FrameMaintainVoice         ;         Yes, go do it (we don't know how yet.. ;) )
                        call BeatMaintainVoice            ;         Do beat maintenance
                        pop hl                            ;         Recover HL and B
                        pop bc
                        jp NextVoiceBeatMaint             ;         Done with this voice
JustBeatMaintenance     push bc                           ;         Do only beat maintenance
                        push hl
                        call BeatMaintainVoice
                        pop hl
                        pop bc
NextVoiceBeatMaint      ld de, VoiceSize                  ;         DE is amount to advance HL to get next voice
                        add hl, de                        ;         Advance to next voice
                        djnz CheckBeatMaint               ;         And loop
                                                          ;     }
                                                          ; }
                        ret                               ; We're done


; -- Master command runs this beat, do it.
NextMasterCmd           ld hl, (MusicMasterPC)            ; HL is address of current delta time {
                        inc hl                            ;     Now HL is address of current command..
                        ld d, (hl)                        ;     D is current master musicop {
                        ld a, d
                        and %11110000                     ;         A is current master musciop without voice number {
                        jp z, StartPatternCmd             ;              Check command. 0 = Start pattern
                                                          ;         }
                                                          ;     }
                                                          ; }
                        ret

; -- Command to start a pattern playing on a voice.
; HL is address of command (NOT deltatime), D is current music op which is = voice number because command code is 0.
; No postcondition obligations.
StartPatternCmd         ld a, d                           ; A is current voice number { (since high bits for start command are 0)
                        add a, a                          ;     Now A is offset into voice status array
                        ld de, hl                         ;     We don't need D any more but we do need the command address, save in DE
                        ld l, a                           ;     VoiceStatus table is seg aligned so address low byte = offset
                        ld h, VoiceStatusSeg              ;     HL is address of address of segment for this voice {
                        ld c, (hl)                        ;         Copy two bytes of address from HL into BC
                        inc hl                            ;
                        ld b, (hl)                        ;     }
                                                          ; }
                                                          ; BC is address of segment for this voice
                        ld hl, bc                         ; HL is address of segment for this voice {
                        ld a, (hl)                        ;     Get voice status byte
                        set 0, a                          ;     It needs beat maintenance now.
                        ld (hl), a                        ;     Store that fact in voice status byte
                        inc de                            ;     DE is address of pattern address {
                        push de                           ;         We'll need that again in a moment
                        inc hl                            ;         Now HL is address of Pattern PC value in voice status structure
                        ex de, hl                         ;         Switch these to allow ldi to work
                        ldi                               ;         Copy 2 bytes of pattern address from HL to DE
                        ldi                               ;         (This clobbers BC but we're not using it)
                        pop hl                            ;         Reset source address to copy it again to Loop PC
                        push hl                           ;         We still need that again
                        ldi
                        ldi
                        pop hl                            ;         We need the address of the pattern address for the last time
                        ld c, (hl)                        ;         Copy the address to BC so BC is address of the actual pattern
                        inc hl
                        ld b, (hl)
                        ld a,(bc)                         ;         A is first byte of the pattern, which will be the initial deltatime
                        ld (de), a                        ;         After all those LDIs DE will be pointing to the byte AFTER the
                                                          ;         Loop PC which is the beat counter
                                                          ;     }
                                                          ; }
                        ld hl, (MusicMasterPC)            ; Move master PC on by 4 bytes
                        ld bc, 4
                        add hl, bc
                        ld (MusicMasterPC), hl            ; And store back into master PC
                        ret

; BeatMaintainVoice. Called from nextbeat with HL pointing to voice's control block and B holding reversed voice number
; No postconditions
BeatMaintainVoice       ld a, NumVoices                   ; Get "real" voice number from countdown loop counter
                        sub b
                        ld d, a
                        ld a, l                           ; Copy HL to IX for indexing stuff below
                        ld ixl, a
                        ld a, h
                        ld ixh, a
                        ld a,(ix+BeatCountdown)           ; Time for next pattern command?
                        cp 0
                        jp z, PatternCommand              ; Yes, go do it
                        dec a                             ; Nope, all we need to do is update beat countdown
                        ld (ix+BeatCountdown), a
                        ret                               ; And we're done

; PatternCommand. Called from BeatMaintainVoice with d holding voice number and ix holding base of voice status structure
PatternCommand          ld hl,(ix+PatternPC)              ; HL is address of current pattern deltatime
                        inc hl                            ; HL is address of current command {
                        ld a,(hl)                         ;     A is current command {
                        bit 7, a                          ;         Is MSB set?
                        jp nz, runNoteCommand             ;         It's a command, not a note
                                                          ;         -- It's a note. Play it
                        push hl                           ;         We'll need the command address again
                        ld h, notetableSeg                ;         Get segment address of note table
                        add a,a                           ;         Notes are 2 bytes, double to get offset in note table
                        ld l,a                            ;         Note table is segment aligned so just setting low bit finds location
                                                          ; } HL is address of tuning values for this note {
                        ld a,d                            ;         AY fine tune register number is voice number * 2, get voice number
                        add a,a                           ;         Double it
                        ld bc, AyRegSelect                ;         BC is port address of AY register selector
                        out (c), a                        ;         Send register selection
                        ld d, a                           ;         Save register selection to use in a moment
                        ld b, $bf                       ;         Only high byte changes to get register write port
                        outi                              ;         Send (HL) to port BC (increments HL and clobbers B but we don't care..
                        ld b, $ff                         ;         .. because we're about to change it back to the reg select port again)
                        ld a, d                           ;         Get the register number back
                        inc a                             ;         Add 1 to it to get the coarse tune register
                        out (c), a                        ;         Select coarse tune register
                        ld b, $bf                         ;         Back to the register write port
                        outi                              ;         And send the coarse tune value from the incremented HL
                                                          ; }
                        pop hl                            ; HL is address of current command {
PatternPCOneByte        inc hl                            ;     HL now points to address of wait time of next command
                        ld (ix+PatternPC), hl             ;     It's the new music PC
                        jp FinishPatternCommand           ; }

; runNoteCommand. Called from PatternCommand if command is knnown to be a non-note.
; HL is address of current command, A is current command.
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



