; Attempt at a SD/AY driver - tuner
; By Mark Green (hyphz)
; Licensed under Creative Commons Attribution 4.0

; Thanks:
; utz@SpecNext
; Alcoholics Anonymous@SpecNext
; Hikaru@SpecNext
; Matt Westcott
; Leeda Kifee
; Cesar Hernandez Bano for Zesarux

AppFilename             equ "tune"                   ; What we're called (for file generation)

AppFirst                equ $8000                       ; First byte of code (uncontended memory)

                        zeusemulate "128K","ULA+"       ; Set the model and enable ULA+

AyRegSelect             equ $fffd     ; On Next, this is also used for chip selection
AyRegWrite              equ $bffd
SetBorder               equ $229b
PrintBC                 equ $1a1b
NextRegSelect           equ $243b     ; Only useful for changing audio mix
NextRegWrite            equ $253b
KempstonJoystick        equ $001f


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


; Start planting code here. (When generating a tape file we start saving from here)

                        org AppFirst              ; Start of application

AppEntry                aysendabc(AyToneEnable, %00111000)
                        aysendabc(AyAmplitudeA, %00001111)

ChangeNote              aysendabc (AyCoarseTuneA, (coarse))
                        aysendabc (AyFineTuneA, (fine))
                        call $0daf
                        ld b, 0
                        ld a, (coarse)
                        ld c, a
                        call PrintBC
                        ld b, 0
                        ld a, (fine)
                        ld c, a
                        call PrintBC
JoystickWait            ld bc, KempstonJoystick
                        in a,(bc)
                        or 0
                        jp z JoystickWait
                        bit 0,a
                        jp nz right
                        bit 1,a
                        jp nz left
                        bit 2,a
                        jp nz down
                        bit 3,a
                        jp z JoystickWait

                        ld a, (fine)
                        inc a
                        ld (fine),a
                        jp ChangeNote
down                    ld a, (fine)
                        dec a
                        ld (fine),a
                        jp ChangeNote
left                    ld a, (coarse)
                        dec a
                        ld (coarse), a
                        jp ChangeNote
right                   ld a, (coarse)
                        inc a
                        ld (coarse), a
                        jp ChangeNote




coarse                  db 0
fine                    db 0




; Stop planting code after this. (When generating a tape file we save bytes below here)
AppLast                 equ *                           ; The last used byte's address

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



