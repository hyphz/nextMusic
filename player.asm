; This is a basic template file for writing 128K Spectrum code.

AppFilename             equ "player"                   ; What we're called (for file generation)

AppFirst                equ $8000                       ; First byte of code (uncontended memory)

                        zeusemulate "128K","ULA+"       ; Set the model and enable ULA+

AyRegSelect             equ $fffd
AyRegWrite              equ $bffd
KempstonJoystick        equ 31

AyCoarseTuneA           equ 1
AyFineTuneA             equ 0
AyAmplitudeA            equ 8
AyAmpPeriodFine         equ 11
AyAmpPeriodCoarse       equ 12
AyAmpShape              equ 13

out16bc                 macro(port, val)
                        ld bc, port
                        out (c), val
                        mend

in16bca                 macro(port)
                        ld bc, port
                        in a,(c)
                        mend

aysendabc               macro(reg, val)
                        ld a, reg
                        out16bc(AyRegSelect, a)
                        ld a, val
                        out16bc(AyRegWrite, a)
                        mend


; Start planting code here. (When generating a tape file we start saving from here)

                        org AppFirst                    ; Start of application

AppEntry                aysendabc(7, 56)
                        aysendabc(AyAmplitudeA, %00010000)
                        aysendabc(AyAmpPeriodFine, $01)
                        aysendabc(AyAmpPeriodCoarse, $06)
                        aysendabc(AyAmpShape, %00001000)

Reset                   ld bc, music
                        ld (music_pointer), bc
Loop                    ld a, (wait_frames)
                        jp z, nextNote
                        dec a
                        ld (wait_frames), a
                        halt
                        jp Loop
nextNote                ld hl, notetable
                        ld ix, (music_pointer)
                        ld a,(ix+0)
                        cp 99
                        jp z, Reset
                        rla
                        and %11111110
                        ld c,a
                        ld b,0
                        add hl,bc
                        aysendabc(AyCoarseTuneA,(hl))
                        inc hl
                        aysendabc(AyFineTuneA,(hl))
                        ld a,(ix+1)
                        ld (wait_frames),a
                        ld bc, 2
                        add ix, bc
                        ld (music_pointer), ix
                        jp Loop

music_pointer           dw 00
wait_frames             db 00
music                   db 12, 10, 13, 10, 14, 10, 15, 10, 99, 00
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


                        output_tap AppFilename+".tap",AppFilename,"",AppFirst,AppLast-AppFirst,3,AppEntry ; A tzx file using the loader



