; This is a basic template file for writing 128K Spectrum code.

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
                        out16bc(AyRegSelect, a)
                        ld a, val
                        out16bc(AyRegWrite, a)
                        mend

                        struct
UpdateStatus            ds 1
PatternPC               ds 2
LoopPC                  ds 2
BeatCountdown           ds 1
VoiceSize               equ .
                        send

                        struct
MasterDeltaTime         ds 1
Command                 ds 1
ParameterA              ds 1
ParameterB              ds 1
ParameterC              ds 1
                        send   ; No length value because length is variable


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


MusicUpdate             ld a, (TempoWait)                 ; Are we waiting for a beat?
                        cp 0                              ; Ie, has TempoWait value reached 0?
                        jp z, NextBeat                    ; It has - go to next beat
                        dec a                             ; It hasn't, we're waiting - decrement frame wait counter
                        ld (TempoWait), a                 ; And store it back into TempoWait counter.
                        ld ix, VoiceStatusBank            ; No beat this frame. But any voices need frame-based maintenance?
                        ld d, NumVoices                   ; D is loop counter for checking
                        ld bc, VoiceSize                  ; BC holds size of a voice record (because we can add it to IX)
CheckVFrameMaint        ld a, (ix+UpdateStatus)           ; Load status byte for current voice
                        bit 1,a                           ; Is bit 1 set?
                        jp nz, NoFrameMaintenance         ; No, no frame maintenance needed
                        push de                           ; Push all the stuff we're using in this loop
                        push ix
                        push bc
                        ; call FrameMaintainVoice         ; Yes, go do it (we don't know how yet ;) )
                        pop bc
                        pop ix
                        pop de
NoFrameMaintenance      dec d                             ; Lower loop counter
                        jp z, DoneFrameMaintenance        ; If it's 0, we're done (don't need to run when =0 because we ran when =NumVoices)
                        add ix, bc                        ; Move IX to point at next voice block
                        jp CheckVFrameMaint               ; And loop
DoneFrameMaintenance    ret                               ; We're done




NextBeat                ld a, (Tempo)                     ; Beat time. Reset tempo clock
                        ld (TempoWait), a
                        ld a, (BeatWait)                  ; Check beat clock for master commands
                        cp 0                              ; Is it 0?
                        jp nz, NoMasterCmd                ; No, We are waiting -> don't run master command
                        call NextMasterCmd                ; Yes, We aren't waiting -> go run it
                        ld bc,(MusicMasterPC)             ; BC holds address of delay for next command
                        ld a,(bc)                         ; A holds delay for next command
                        ld (BeatWait), a                  ; Load it into wait
                        jp MasterCmdDone                  ; Skip timer stuff below
NoMasterCmd             dec a                             ; We're waiting, count down wait timer
                        ld (BeatWait), a                  ; Put it back into wait
MasterCmdDone           ld ix, VoiceStatusBank            ; Now do beat AND frame maintenance.
                        ld d, NumVoices                   ; D is loop counter for checking
CheckBeatMaint          ld a, (ix+UpdateStatus)           ; Load status byte for current voice
                        bit 0,a                           ; Is bit 0 set?
                        jp z, NextVoiceBeatMaint          ; If not, Nothing needed (nothing would ever need frame but not beat maintenance)
                        bit 1,a                           ; Is bit 1 set?
                        jp z, JustBeatMaintenance         ; If not, Only beat maintenance needed
                        push de                           ; Need both
                        push ix
                        ; call FrameMaintainVoice         ; Yes, go do it (we don't know how yet.. ;) )
                        call BeatMaintainVoice
                        pop ix
                        pop de
                        jp NextVoiceBeatMaint             ; Done with this voice
JustBeatMaintenance     push de                           ; Do only beat maintenance
                        push ix
                        call BeatMaintainVoice
                        pop ix
                        pop de
NextVoiceBeatMaint      dec d                             ; Lower voice loop counter
                        jp z, DoneBeatMaintenance         ; If it's 0, we're done (don't need to run when =0 because we ran when =NumVoices)
                        ld bc, VoiceSize                  ; Load voice size into BC to add it to IX
                        add ix, bc                        ; Move IX to point at next voice block
                        jp CheckBeatMaint                 ; And loop
DoneBeatMaintenance     ret                               ; We're done


NextMasterCmd           ld ix, (MusicMasterPC)            ; IX is current delta time
                        ld d, (ix+1)                      ; This will be command
                        ld a, d                           ; Mask off voice number
                        and %11110000
                        jp z, StartPatternCmd             ; Check command. 0 = Start pattern
                        ret

StartPatternCmd         ld e, d                           ; Form voice number as a 16-bit value in DE
                        ld d, 0
                        ld iy, de                         ; IY now holds voice number
                        add iy, iy                        ; Voice bank addresses are 2 bytes. IY now holds offset for voice bank address table
                        ld bc, VoiceStatusLoc             ; BC is base of Voice bank address table
                        add iy, bc                        ; IY is address of voice bank address
                        ld bc, (iy)                       ; BC is address of voice bank
                        ld iy, bc                         ; Put it back into IY so we can use indexing
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

; BeatMaintainVoice. Called with IX pointing to voice's control block and D holding reversed voice number
BeatMaintainVoice       ld a, NumVoices                   ; Put real voice number into D
                        sub d
                        ld d, a
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
                        ld hl, notetable                  ; It's a note, cue up note table
                        add a,a                           ; Notes are 2 bytes, double to get offset in note table
                        ld c,a                            ; Build note table offset in bc
                        ld b,0
                        add hl,bc                         ; Add offset to base, HL is now note table address of note
                        ld a,d
                        add a,a
                        ld e,a
                        inc e
                        aysendabc(e,(hl))                 ; Get coarse tune value from note table
                        inc hl                            ; Go to next byte in note table
                        dec e
                        aysendabc(e,(hl))                 ; Get fine tune value from note table
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





Tempo                   db 13                              ; Number of frames per beat count

TempoWait               db 0

VoiceStatusBank         loop NumVoices
                          loop VoiceSize
                            db 00
                          lend
                        lend

CurVoiceAddress = VoiceStatusBank
VoiceStatusLoc          loop NumVoices
                           dw CurVoiceAddress
                           CurVoiceAddress = CurVoiceAddress + VoiceSize
                        lend



MusicMasterPC           dw 00
BeatWait                db 00


music                   db 0, 0
                        dw pattern
                        db 2, 1
                        dw pattern
                        db 255


pattern                 db 0, 12, 1, 16, 1, 19, 1, 16, 1, %10000000

; 8 octaves, note indexes 0-95, from 128 documentation
notetable               db 13,16,12,84,11,163,10,252,10,94,9,201,9,60,8,184,8,58
                        db 7,196,7,85,6,235,6,136,6,42,5,209,5,126,5,47,4,228,4,158
                        db 4,92,4,29,3,226,3,170,3,117,3,68,3,21,2,232,2,191,2,151
                        db 2,114,2,79,2,46,2,14,1,241,1,213,1,186,1,162,1,138,1,116
                        db 1,95,1,75,1,57,1,39,1,23,1,7,0,248,0,234,0,221,0,209,0,197
                        db 0,186,0,175,0,165,0,156,0,147,0,139,0,131,0,124,0,117,0,110
                        db 0,104,0,98,0,93,0,87,0,82,0,78,0,73,0,69,0,65,0,62,0,58,0,55
                        db 0,52,0,49,0,46,0,43,0,41,0,39,0,36,0,34,0,32,0,31,0,29,0,27
                        db 0,26,0,24,0,23,0,21,0,20,0,19,0,18,0,17,0,16,0,15,0,14,0,13


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



