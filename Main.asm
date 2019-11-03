; ------------------------------------------------------------------------------
; Hello World for a 16K expanded VIC20
; Written 2019-11-03 by Carl Muller
; MIT license
; Compiles with CBM prg studio
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Hardware registers
VIC_HPOS=$9000
VIC_VPOS=$9001
VIC_HSIZE=$9002
VIC_VSIZE=$9003
VIC_RASTER=$9004
VIC_VRAM=$9005
VIC_HLIGHT=$9006
VIC_VLIGHT=$9007
VIC_POT1=$9008
VIC_POT2=$9009
VIC_ALTO=$900A
VIC_TENOR=$900B
VIC_SOPRANO=$900C
VIC_NOISE=$900D
VIC_VOLUME=$900E
VIC_COLOUR=$900F

; Hardware constants
COL_BLACK=0
COL_WHITE=1
COL_RED=2
COL_CYAN=3
COL_MAGENTA=4
COL_GREEN=5
COL_BLUE=6
COL_YELLOW=7

; ------------------------------------------------------------------------------
; Main memory map
SCREEN_BUFFER=$1000
; CODE is 1200..13ff
CHARSET_BUFFER=$1400
BITMAP_BUFFER=$1800
CBM_CHARSET=$8400
COLOUR_BUFFER=$9400

; ------------------------------------------------------------------------------
; Constants for this game
SCREEN_WIDTH=24
SCREEN_HEIGHT=12
ScrBitmap = SCREEN_BUFFER+SCREEN_WIDTH*2+4


; ------------------------------------------------------------------------------
; Variables
ptr=251
ptr2=253
temp=255
accum=253


; ------------------------------------------------------------------------------
        ; BASIC header to enter the machine code
        *=$1201
        byte $0E,$12,$E3,$07, $9E,$20,$28
        byte $34,$36,$32,$34
        byte $29,$00,$00,$00

; ------------------------------------------------------------------------------
; Main entry point
start   SEI
        CLD
        JSR CreateBitmap
        jsr CopyCharset
        jsr PrintHello
        jsr DrawBitmap
        jmp forever

; ------------------------------------------------------------------------------
; Halt the game while displaying a raster effect in the border colour
forever lda VIC_RASTER
@floop  cmp VIC_RASTER
        beq @floop
        jsr @nops
        jsr @nops
        nop
        nop
        nop
        and #7
        ora #COL_BLUE*16
        sta VIC_COLOUR
        jmp forever

@nops
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        rts


; ------------------------------------------------------------------------------
; Copy 64 characters of the 8*8 built-in font to a 8*16 font
CopyCharset
        lda #<CBM_CHARSET
        sta ptr
        lda #>CBM_CHARSET
        sta ptr+1
        lda #<CHARSET_BUFFER+8
        sta ptr2
        lda #>CHARSET_BUFFER
        sta ptr2+1
        ldx #64-1

@cc1p2  ldy #7
@cc1p1  lda (ptr),Y
        sta (ptr2),Y
        dec ptr2
        sta (ptr2),Y
        dey
        bpl @cc1p1

        lda ptr
        clc
        adc #8
        sta ptr
        bcc @noinccc1
        inc ptr+1
@noinccc1
        lda ptr2
        clc
        adc #24
        sta ptr2
        bcc @noinccc2
        inc ptr2+1
@noinccc2
        dex
        bne @cc1p2
        rts

; ------------------------------------------------------------------------------
; Print hello world on the screen
PrintHello
        ldx #0
        lda HelloText,X
@loop   and #63
        ora #64
        sta SCREEN_BUFFER,X
        lda #COL_WHITE
        sta COLOUR_BUFFER,X
        inx
        lda HelloText,X
        bne @loop
        rts

HelloText
        text "HELLO WORLD!"
        byte 0

; ------------------------------------------------------------------------------
; Create a screen that includes a bitmap buffer
CreateBitmap
        lda #127
        ldx #0
clrloop sta SCREEN_BUFFER,X
        sta SCREEN_BUFFER+$100,X
        dex
        bne clrloop

        lda #COL_GREEN
        ldx #0
colloop sta COLOUR_BUFFER,X
        sta COLOUR_BUFFER+$100,X
        dex
        bne colloop

        lda #128
        sta temp
        ldy #0

columns lda #<ScrBitmap
        sta ptr
        lda #>ScrBitmap
        sta ptr+1
        ldx #8
chrloop lda temp
        sta (ptr),Y
        lda ptr
        clc
        adc #SCREEN_WIDTH
        sta ptr
        bcc noinc1
        inc ptr+1
noinc1  inc temp
        dex
        bne chrloop
        iny
        cpy #16
        bne columns

        ; Setup a crosshatch using the ? character
        lda #$55
        sta BITMAP_BUFFER-16
        sta BITMAP_BUFFER-14
        sta BITMAP_BUFFER-12
        sta BITMAP_BUFFER-10
        sta BITMAP_BUFFER-8
        sta BITMAP_BUFFER-6
        sta BITMAP_BUFFER-4
        sta BITMAP_BUFFER-2
        asl A
        sta BITMAP_BUFFER-15
        sta BITMAP_BUFFER-13
        sta BITMAP_BUFFER-11
        sta BITMAP_BUFFER-9
        sta BITMAP_BUFFER-7
        sta BITMAP_BUFFER-5
        sta BITMAP_BUFFER-3
        sta BITMAP_BUFFER-1

        ; Set the bitmap up to a non-blank value
        lda #0
        ldx #0
        clc
bclr    sta BITMAP_BUFFER,X
        sta BITMAP_BUFFER+$100,X
        sta BITMAP_BUFFER+$200,X
        sta BITMAP_BUFFER+$300,X
        sta BITMAP_BUFFER+$400,X
        sta BITMAP_BUFFER+$500,X
        sta BITMAP_BUFFER+$600,X
        sta BITMAP_BUFFER+$700,X
        adc #1
        inx
        bne bclr

        ; Setup the VIC hardware registers (for non-zero values)
        ldx #15
loopvic lda VicRegs,X
        beq skipvic
        sta $9000,X
skipvic dex
        bpl loopvic

        rts


; ------------------------------------------------------------------------------
; The initial values of the VIC hardware registers
VicRegs
        byte 10 ; VIC_HPOS
        byte 40 ; VIC_VPOS
        byte SCREEN_WIDTH ; VIC_HSIZE
        byte 25 ; (12*2+1) ; VIC_VSIZE
        byte 0 ; VIC_RASTER  do not write to this
        byte $cc ; (12+16*12) ; VIC_VRAM
        byte 0 ; VIC_HLIGHT  do not write to this
        byte 0 ; VIC_VLIGHT  do not write to this
        byte 0 ; VIC_POT1  do not write to this
        byte 0 ; VIC_POT2  do not write to this
        byte 0 ; VIC_ALTO
        byte 0 ; VIC_TENOR
        byte 0 ; VIC_SOPRANO
        byte 0 ; VIC_NOISE
        byte 0 ; VIC_VOLUME
        byte $63 ; (COL_CYAN+16*COL_BLUE) ; VIC_COLOUR


; ------------------------------------------------------------------------------
; Draw a bitmap using a pixel calculation function.
; Dither the pixel values in one dimension (floyd-steinberg would be better)
DrawBitmap
        lda #0
        sta accum
        ldy #0

@DrawRow
        lda #<BITMAP_BUFFER
        sta ptr
        lda #>BITMAP_BUFFER
        sta ptr+1
        ldx #0
@DrawOne
        jsr CalcPixel
        adc accum
        sta accum
        sec
        sbc #16
        bcc @dplow
        sta accum
        lda (ptr),Y
        rol A
        sta (ptr),Y
        jmp @dphigh
@dplow   lda (ptr),Y
        asl A
        sta (ptr),Y
@dphigh
        inx
        cpx #128
        beq @rowend
        txa
        and #7
        bne @DrawOne
        lda ptr
        clc
        adc #128
        sta ptr
        bcc @noincp2
        inc ptr+1
@noincp2
        jmp @DrawOne

@rowend iny
        cpy #128
        bne @DrawRow
        rts

; ------------------------------------------------------------------------------
; Calculate the value of a pixel
; Input x,y are 0..127
; Output: A = 16 for on
CalcPixel
        stx temp
        tya
        clc
        adc temp
        lsr a
        lsr a
        lsr a
        lsr a
        rts
        
; ------------------------------------------------------------------------------
