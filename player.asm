; Attempt at a SD/AY driver
; By Mark Green (hyphz)
; Licensed under Creative Commons Attribution 4.0

; Thanks:
; utz@SpecNext
; Alcoholics Anonymous@SpecNext
; Hikaru@SpecNext
; Matt Westcott
; Leeda Kifee
; Cesar Hernandez Bano for Zesarux
; Neil Mottersheand and Simon Brattel for Zeus (apart from the *-1 thing)

AppFilename             equ "player"                   ; What we're called (for file generation)

AppFirst                equ $8000                       ; First byte of code (uncontended memory)

                        zeusemulate "128K","ULA+"       ; Set the model and enable ULA+

AyRegSelect             equ $fffd     ; On Next, this is also used for chip selection
AyRegWrite              equ $bffd
SetBorder               equ $229b
PrintBC                 equ $1a1b
NextRegSelect           equ $243b     ; Only useful for changing audio mix
NextRegWrite            equ $253b

; Mostly just for reference, sound chip register numbers
AyCoarseTuneA           equ 1
AyFineTuneA             equ 0
AyCoarseTuneB           equ 3
AyFineTuneB             equ 2
AyCoarseTuneC           equ 5
AyFineTuneC             equ 4
AyNoisePeriod           equ 6
AyToneEnable            equ 7
AyAmplitudeA            equ 8
AyAmplitudeB            equ 9
AyAmplitudeC            equ 10
AyAmpPeriodFine         equ 11
AyAmpPeriodCoarse       equ 12
AyAmpShape              equ 13

SidFineTuneA            equ 0
SidCoarseTuneA          equ 1
SidPulseLowA            equ 2
SidPulseHighA           equ 3
SidWaveformA            equ 4
SidADA                  equ 5
SidSRA                  equ 6
SidFineTuneB            equ 7
SidCoarseTuneB          equ 8
SidPulseLowB            equ 9
SidPulseHighB           equ 10
SidWaveformB            equ 11
SidADB                  equ 12
SidSRB                  equ 13
SidFineTuneC            equ 14
SidCoarseTuneC          equ 15
SidPulseLowC            equ 16
SidPulseHighC           equ 17
SidWaveformC            equ 18
SidADC                  equ 19
SidSRC                  equ 20
SidFilterCutoffLow      equ 21
SidFilterCutoffHigh     equ 22
SidFilterResonance      equ 23
SidVolume               equ 24

NumVoices               equ 16

                        struct
UpdateStatus            ds 1
PatternPC               ds 2
LoopPC                  ds 2
BeatCountdown           ds 1
Stage                   ds 1
Instrument              ds 2
AmplitudePC             ds 2
VoiceSize               equ .
                        send

                        struct
AmplitudeCurve          ds 2
EndAmplitudeCurve       ds 2
InstrumentSize          equ .
                        send

                        struct
AY1Buffer               ds 14
AY2Buffer               ds 14
AY3Buffer               ds 14
SIDBuffer               ds 25
BufferSize              equ .
                        send



; Start planting code here. (When generating a tape file we start saving from here)

                        org AppFirst                    ; Start of application

AppEntry                ld sp, $ff46                    ; Sync zeus and zesarux stack location
                        call MusicInit
TestLoop                call MusicUpdate
                        halt
                        jp TestLoop


MusicInit               ld a,%00111000                   ; Enable tone on all channels
                        ld (outputBuffer+13-AyToneEnable), a
                        ld a,%00001111
                        ld (outputBuffer+13-AyAmplitudeA), a
                        ld a,%00001111
                        ld (outputBuffer+13-AyAmplitudeB), a
                        ld a,%00001111
                        ld (outputBuffer+13-AyAmplitudeC), a
                        ld hl, music                      ; Set musicPointer to address of start of music
                        ld (MusicMasterPC), hl
                        ld a, 0                           ; Set initial tempoWait to 0 so music starts immediately
                        ld (TempoWait), a
                        ld a, (hl)                        ; Set initial beatWait to delay for first command
                        ld (BeatWait), a
                        ret

; Update 1 - crank out data from buffer to ports.
MusicUpdate             ld hl, outputBuffer               ; HL will be untouched through the process, moved on by OUTIs
                        ld bc, AyRegSelect                ; We should only need to load this once
                        ld a, %11111111                   ; Turns on both stereo channels and selects AY1
                        out (bc),a                        ; Select AY1
                        ld d, 13                          ; Highest AY register
                        call DumpBufferLoop

; DEBUG: If emulator doesn't pay attention to the Next chip select, we must stop here, or later
; writes will overwrite values in the one chip that is emulated
                        jp NoNextSoundEmu


                        ld b, high(AyRegSelect)
                        dec a
                        out (bc),a                        ; Select AY2
                        ld d, 13
                        call DumpBufferLoop
                        ld b, high(AyRegSelect)
                        dec a
                        out (bc),a                        ; Select AY3
                        ld d, 13
                        call DumpBufferLoop
                        ld b, high(AyRegSelect)
                        dec a
                        out (bc),a                        ; Select SID
                        ld d, 22
                        call DumpBufferLoop
NoNextSoundEmu          jp FrameCycle

DumpBufferLoop          ld b, high(AyRegSelect)           ; Cue up to select D'th register
                        out (bc), d                       ; Select it
                        ld b, $c0                         ; Changes BC to register write, after the dec outi does
                        outi                              ; Write buffer value to register and increment HL
                        dec d                             ; Count down register number (buffer has registers in reverse order)
                        jp nz, DumpBufferLoop             ; If there are registers left, go back
                        ld b, high(AyRegSelect)           ; Last one with D=0
                        out (bc), d
                        ld b, $c0                         ; Changes BC to register write, after the dec outi does
                        outi
                        ret




; -- See if there's a beat this frame or not
FrameCycle              ld a, (TempoWait)                 ; Load tempo counter
                        sub 1                             ; Subtract one from it
                                                          ; (SUB takes 3 more states than DEC but sets the carry flag properly,
                                                          ; which saves us from doing a CP to test for zero, which would take 7 more)
                        jp c, NextBeat                    ; If subtracting 1 overflowed, it was 0, so go process the beat
                        ld (TempoWait), a                 ; It didn't overflow. Store it back into TempoWait counter
                                                          ; -- No beat this frame. Do frame maintenance
                        ld hl, VoiceStatusBank            ; HL is address of voice to check {
                        ld b, NumVoices                   ;     B is loop counter for checking {
CheckVFrameMaint        ld a, (hl)                        ;         Load status byte for current voice
                        or 0                              ;            Is voice active?
                        jp z, NoFrameMaintenance          ;         No, this voice doesn't need frame maintenance
                        push hl                           ;         Save HL and BC (can't just save B, stack values have to be 16bit)
                        push bc
                        call FrameMaintainVoice           ;         Do frame maintenance (we don't know how yet ;) )
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
CheckNextMaster         sub 1                             ; Same trick as above to set carry
                        jp nc, NoMasterCmd                ; If it didn't overflow it wasn't 0, we are waiting, don't run master command
ReptMasterCmd           call NextMasterCmd                ; Yes, We aren't waiting -> go run it
                                                          ; Back from doing master command, set delay for next master command
                        ld hl,(MusicMasterPC)             ; HL holds address of delay for next command
                        ld a,(hl)                         ; A holds delay for next command
                        jp CheckNextMaster                ; Process it this frame

NoMasterCmd             ld (BeatWait), a                  ; Put new delta wait (from command, or subtraction) back into delta timer
                                                          ; -- Do beat and frame maintenance on a beat frame
                        ld hl, VoiceStatusBank            ; HL is address of voice to check {
                        ld b, NumVoices                   ;     B is loop counter for checking {
CheckBeatMaint          ld a, (hl)                        ;         A is current voice's status byte {
                        or 0                              ;             Is bit 0 set?
                        jp z, NoBeatMaintenance           ;             If not, Nothing needed (nothing would ever need frame but not beat maintenance)
                        push bc, hl                       ;         Store HL and B                                               ;
                        call BeatMaintainVoice            ;         Do beat maintenance
                        pop hl, bc
                        push bc, hl
                        call FrameMaintainVoice           ;         Yes, go do it (we don't know how yet.. ;) )
                        pop hl, bc                        ;         Recover HL and B
NoBeatMaintenance       ld de, VoiceSize                  ;         DE is amount to advance HL to get next voice
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
MasterCommandPanic      ld a, 04
                        call SetBorder
                        jp MasterCommandPanic


; -- Command to start a pattern playing on a voice.
; HL is address of command (NOT deltatime), D is current music op which is = voice number because command code is 0.
; No postcondition obligations.
StartPatternCmd         ld a, d                           ; A is current voice number (since high bits for start command are 0)
                        add a, a                          ; Now A is offset into voice status array
                        ld de, hl                         ; Copy address of the command into DE
                        ld c, a                           ; VoiceLoc table is seg aligned so address low byte = offset
                        ld b, high(VoiceStatusLoc)        ; BC is address of address of segment for this voice
                        ld a, (bc)                        ; Copy two bytes of address into HL
                        ld l, a
                        inc bc
                        ld a, (bc)                        ;
                        ld h, a                           ; Now HL is address of status segment for this voice
                        ld a, 1                           ; Mark voice active (active flag is offset 0)
                        ld (hl), a                        ;
                        inc de                            ; DE is now address of pattern address
                        inc hl                            ; HL is now address of Pattern PC in voice segment
                        ex de, hl                         ; Switch these to allow ldi to work
                        push hl                           ; Store address of pattern address on stack
                        ldi                               ; Copy 2 bytes of pattern address from HL to DE
                        ldi                               ; (This clobbers BC, but we're not using it)
                        pop hl                            ; Reset source address to copy it again to Loop PC
                        push hl                           ;
                        ldi                               ; Copy pattern address to loop PC
                        ldi                               ;
                        pop hl                            ; We need the address of the pattern address for the last time
                        ld c, (hl)                        ; Copy the address to BC so BC is address of the actual pattern
                        inc hl
                        ld b, (hl)
                        ld a,(bc)                         ; A is first byte of the pattern, which will be the initial deltatime
                        ld (de), a                        ; After all those LDIs, DE points to beat countdown
                        inc de                            ; Start new pattern at stage 0
                        ld a, 0
                        ld (de), a
                        inc de                            ; Now DE points to instrument address
                        ld hl, BasicInstrument            ; Set to basic instrument
                        ld a,l
                        ld (de), a
                        inc de
                        ld a,h
                        ld (de), a
                        inc de
                        ldi                               ; HL points to basic instrument start, DE points to instrument PC
                        ldi
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
                        ld e, 0
                        ld a,(ix+BeatCountdown)           ; Time for next pattern command?
PatternReEntry          sub 1
                        jp c, PatternCommand              ; Yes, go do it
                        ld (ix+BeatCountdown), a
                        or 0                              ; Is beat countdown now 0 (this was last beat?)
                        ret nz                            ; No, we're done
                        ld a, e                           ; Was a single beat note played this beat?
                        or 0
                        ret nz                            ; Yes, it's using single beat pattern
                        ld hl, (ix+Instrument)            ; Last beat of note. Need to change to release pattern
                        inc hl
                        inc hl
                        ld a, (hl)
                        ld (ix+AmplitudePC), a
                        inc hl
                        ld a, (hl)
                        ld (ix+AmplitudePC+1), a
                        ret                               ; And we're done



; PatternCommand. Called from BeatMaintainVoice with d holding voice number and ix holding base of voice status structure
PatternCommand          ld hl,(ix+PatternPC)              ; HL is address of current pattern deltatime
                        inc hl                            ; HL is address of current command {
                        ld a,(hl)                         ;     A is current command {
                        bit 7, a                          ;         Is MSB set?
                        jp nz, runNoteCommand             ;         It's a command, not a note
                                                          ;         -- It's a note. Play it
                        push hl                           ;         We'll need the command address again
                        ld h, high(notetable)             ;         Get segment address of note table
                        add a,a                           ;         Notes are 2 bytes, double to get offset in note table
                        ld l,a                            ;         Note table is segment aligned so just setting low bit finds location
                                                          ; } HL is address of tuning values for this note {
                        ld a,d                            ;         AY fine tune register number is voice number * 2, get voice number
                        add a,a                           ;         Double it
                        neg                               ; Negate and add 13 to get offset into buffer
                        add a, 13
                        ld b, high(outputBuffer)          ; Load up buffer address in BC
                        ld c, a
                        ld a, (hl)                        ; Load coarse and fine tune registers in buffer
                        ld (bc), a
                        dec c
                        inc hl
                        ld a, (hl)
                        ld (bc),a
                                                          ; }
                        pop hl                            ; HL is address of current command {
PatternPCOneByte        inc hl                            ; HL now points to address of wait time of next command
                        ld (ix+PatternPC), hl             ; It's the new music PC
                        ld a, (hl)                        ; Get next note wait. Is it 1?
                        sub 1                             ; We'll use this in a moment
                        ld hl, (ix+Instrument)            ; HL is address of instrument structure
                        ld e, 0                           ; Clear one beat flag
                        jp nz, MoreThanOneBeat            ; If next note wait wasn't 1, skip..
                        ld de, 4                          ; Add 4 to HL to point at one beat amp table address
                        add hl, de
                        ld e,1                            ; Set one beat flag
MoreThanOneBeat         ld a, (hl)                        ; Copy amp table address from instrument
                        ld (ix+AmplitudePC), a
                        inc hl
                        ld a, (hl)
                        ld (ix+AmplitudePC+1), a
                        jp FinishPatternCommand           ; }

; runNoteCommand. Called from PatternCommand if command is knnown to be a non-note.
; HL is address of current command, A is current command.
runNoteCommand          and %01111111                     ; Mask off command indicator bit
                        jp z, PatternLoopCommand          ; Command 0, loop
CommandPanic            jp CommandPanic


PatternLoopCommand      ld bc, (ix+LoopPC)                ; Set patternPC to loopPC
                        ld (ix+PatternPC), bc
                        jp FinishPatternCommand           ; Since we just changed patternPC don't calculate it for "next" command

FinishPatternCommand    ld a, 0
                        call SetBorder
                        ld bc,(ix+PatternPC)              ; Get wait value for next command
                        ld a,(bc)
                        jp PatternReEntry

; Called with HL = address of voice status block, B is inverted voice number.
; Voice is known to be active.
; Note - this potentially runs 16 times per frame. It should probably be optimized ;)
FrameMaintainVoice      ld a, b                    ; Double inverted voice number for index into amp location table
                        dec a
                        ld de, hl                  ; Store HL for the moment
                        add a, a
                        ld l, a                    ; HL is address of address of amplitude buffer value
                        ld h, high(ampPointer)
                        ld c, (hl)
                        inc hl
                        ld b, (hl)                 ; BC is now address of amplitude output byte for this voice
                        ld hl, de                  ; Get back the voice status block address we saved earlier
                        ld de, AmplitudePC
                        add hl, de                 ; HL now points to amplitude PC in voice status block
                        ld e, (hl)                 ; Get address of actual amplitude value
                        inc hl
                        ld d, (hl)
                        ld a, (de)                 ; Get actual amplitude value
                        ld (bc), a                 ; Store it in amplitude byte
                        dec hl                     ; Move HL back to start of amplitude PC value
                        inc de                     ; Move DE on to linked list pointer in amplitude
                        ex de, hl                  ; Swap these two
                        ldi                        ; Copy linked list pointer into amplitude PC value
                        ldi
                        ret

; ----------- Variables

                        align $0100

CurVoiceAddress = VoiceStatusBank
VoiceStatusLoc          loop NumVoices
                           dw CurVoiceAddress
                           CurVoiceAddress = CurVoiceAddress + VoiceSize
                        lend

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
                        db 26, 0, 24, 0, 23, 0, 21, 0, 20, 0, 19, 0, 18, 0, 17, 0, 16, 0, 15, 0, 14, 0, 13, 0, 0, 0



notetableSeg            equ (notetable >> 8)

                        align $0100

; Outputbuffer stores register outputs in REVERSE order (to make loop faster)
outputBuffer            loop BufferSize           ; 3 AYs (14 * 3) + 1 SID (25) = 67
                          db 0
                        lend

; Quick reference to amplitude positions in output buffer based on inverted voice number
                        align $0100
ampPointer              dw 0
                        dw outputBuffer + SIDBuffer
                        dw outputBuffer + SIDBuffer
                        dw outputBuffer + SIDBuffer
                        dw 0
                        dw outputBuffer + AY3Buffer + (13 - AyAmplitudeC)
                        dw outputBuffer + AY3Buffer + (13 - AyAmplitudeB)
                        dw outputBuffer + AY3Buffer + (13 - AyAmplitudeA)
                        dw 0
                        dw outputBuffer + AY2Buffer + (13 - AyAmplitudeC)
                        dw outputBuffer + AY2Buffer + (13 - AyAmplitudeB)
                        dw outputBuffer + AY2Buffer + (13 - AyAmplitudeA)
                        dw 0
                        dw outputBuffer + AY1Buffer + (13 - AyAmplitudeC)
                        dw outputBuffer + AY1Buffer + (13 - AyAmplitudeB)
                        dw outputBuffer + AY1Buffer + (13 - AyAmplitudeA)




BasicAmpCurve           db $05:dw .+2
                        db $0f:dw .+2
                        db $0c:dw .+2
                        db $0c:dw .-1

BasicRelease            db $0c:dw .+2
                        db $0c:dw .+2
                        db $0c:dw .+2
                        db $0c:dw .+2
                        db $0c:dw .+2
                        db $05:dw .+2
                        db $00:dw .-1

SawtoothMaybe           db $0c:dw .+2
                        db $0e:dw .+2
                        db $0f:dw SawtoothMaybe

OneBeatCurve            db $05:dw .+2
                        db $0f:dw .+2
                        db $0c:dw .+2
                        db $0c:dw .-1
                        db $0c:dw .+2
                        db $0c:dw .+2
                        db $05:dw .-1




BasicInstrument         dw SawtoothMaybe, BasicRelease, OneBeatCurve


Tempo                   db 7                              ; Number of frames per beat count

music                   db 0, 0
                        dw pattern_arp
                       ; db 0, 1
                       ; dw pattern_bass
                        db 12, 2
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

pattern_mel             db 0, 52, 3, 48, 1, 48, 3, 50, 1, 50, 2, 52, 1, 53, 1, 52, 3, 48, 1, 48, 3, 45, 1, 43, 4, $80




; Stop planting code after this. (When generating a tape file we save bytes below here)
AppLast                 equ *                           ; The last used byte's address

                        mem_var VoiceStatusLoc, * - VoiceStatusLoc
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



